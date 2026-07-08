package main

import (
	"context"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/zhaolang/heartlock/internal/config"
	"github.com/zhaolang/heartlock/internal/crypto"
	"github.com/zhaolang/heartlock/internal/migrations"
	"github.com/zhaolang/heartlock/internal/handler"
	"github.com/zhaolang/heartlock/internal/middleware"
	"github.com/zhaolang/heartlock/internal/repository"
	"github.com/zhaolang/heartlock/internal/service"
)

func main() {
	// 加载配置
	cfg, err := config.Load()
	if err != nil {
		slog.Error("failed to load config", "error", err)
		os.Exit(1)
	}

	// 初始化结构化日志
	setupLogger(cfg.Env)

	slog.Info("starting HeartLock server",
		"version", cfg.Version,
		"env", cfg.Env,
		"port", cfg.Port,
	)

	// 连接数据库
	db, err := connectDB(cfg)
	if err != nil {
		slog.Error("failed to connect to database", "error", err)
		os.Exit(1)
	}
	defer db.Close()
	slog.Info("database connected")

	// 执行数据库迁移
	if err := migrations.RunMigrations(db); err != nil {
		slog.Error("failed to run database migrations", "error", err)
		os.Exit(1)
	}
	slog.Info("database migrations completed")

	// 初始化 KMS 密钥管理
	kms, err := crypto.NewKMS(cfg.MasterKey)
	if err != nil {
		slog.Error("failed to initialize KMS", "error", err)
		os.Exit(1)
	}

	// 初始化 Token 管理器
	tokenMgr := crypto.NewTokenManager(cfg.JWTSecret, cfg.JWTExpiryHours)

	// --- 依赖注入 ---

	// Repository 层
	userRepo := repository.NewUserRepo(db)
	lockRepo := repository.NewLockRepo(db)
	pushRepo := repository.NewPushRepo(db)
	logRepo := repository.NewOperationLogRepo(db)

	// Service 层
	pushService := service.NewPushService(pushRepo, cfg.HuaweiPushAppID, cfg.HuaweiPushAppSecret)
	authService := service.NewAuthService(userRepo, lockRepo, pushRepo, logRepo, kms, tokenMgr)
	lockService := service.NewLockService(lockRepo, userRepo, pushService, logRepo, kms)

	// Handler 层
	healthHandler := handler.NewHealthHandler(db, cfg.Version)
	authHandler := handler.NewAuthHandler(authService)
	lockHandler := handler.NewLockHandler(lockService)
	pushHandler := handler.NewPushHandler(pushService)

	// --- 路由配置 ---
	r := chi.NewRouter()

	// 全局中间件（按顺序）
	r.Use(middleware.RequestID)
	r.Use(middleware.Logging)
	r.Use(middleware.Recovery)
	r.Use(middleware.CORS)

	// 健康检查（公开路由）
	r.Get("/health", healthHandler.Health)

	// API V1 路由
	r.Route("/v1", func(r chi.Router) {
		// 无需鉴权的路由
		r.Group(func(r chi.Router) {
			r.Use(middleware.LoginRateLimit)
			r.Post("/auth/register", authHandler.Register)
			r.Post("/auth/login", authHandler.Login)
		})

		// 需 JWT 鉴权的路由
		r.Group(func(r chi.Router) {
			r.Use(middleware.Auth(tokenMgr))

			// 认证模块
			r.Post("/auth/phone-authorize", authHandler.AuthorizePhone)
			r.Delete("/auth/account", authHandler.DeleteAccount)

			// 心锁模块
			r.Get("/heart-locks", lockHandler.List)
			r.Post("/heart-locks", lockHandler.Create)
			r.Get("/heart-locks/{id}", lockHandler.GetDetail)
			r.Patch("/heart-locks/{id}/revoke", lockHandler.Revoke)
			r.Delete("/heart-locks/{id}", lockHandler.Destroy)
			r.Post("/heart-locks/{id}/invitation-card", lockHandler.GenerateInvitationCard)

			// 推送模块
			r.Post("/push/token", pushHandler.RegisterToken)
			r.Delete("/push/token", pushHandler.DeleteToken)
		})
	})

	// 创建 HTTP 服务器
	server := &http.Server{
		Addr:         ":" + cfg.Port,
		Handler:      r,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	// 启动定时清理任务（RULE-006d: 操作日志保留 7 天, RULE-024a: REVOKED 元数据保留 30 天）
	startCleanupJobs(logRepo, lockRepo)

	// 启动服务器（在 goroutine 中）
	go func() {
		slog.Info("server listening", "addr", server.Addr)
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			slog.Error("server error", "error", err)
			os.Exit(1)
		}
	}()

	// 优雅关闭
	gracefulShutdown(server, db)
}


// startCleanupJobs 启动定时清理任务
func startCleanupJobs(logRepo *repository.OperationLogRepo, lockRepo *repository.LockRepo) {
	// 操作日志清理 - 每小时执行一次（RULE-006d）
	go func() {
		ticker := time.NewTicker(1 * time.Hour)
		defer ticker.Stop()
		cleanupOperationLogs(logRepo)
		for range ticker.C {
			cleanupOperationLogs(logRepo)
		}
	}()

	// 已撤回心锁元数据清理 - 每天凌晨3点执行（RULE-024a）
	go func() {
		for {
			now := time.Now()
			next := time.Date(now.Year(), now.Month(), now.Day(), 3, 0, 0, 0, now.Location())
			if next.Before(now) || next.Equal(now) {
				next = next.Add(24 * time.Hour)
			}
			time.Sleep(next.Sub(now))
			cleanupRevokedLocks(lockRepo)
		}
	}()

	slog.Info("cleanup jobs scheduled")
}

func cleanupOperationLogs(logRepo *repository.OperationLogRepo) {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	deleted, err := logRepo.CleanupOld(ctx)
	if err != nil {
		slog.Error("cleanup operation logs failed", "error", err)
		return
	}
	if deleted > 0 {
		slog.Info("cleaned up old operation logs", "count", deleted)
	}
}

func cleanupRevokedLocks(lockRepo *repository.LockRepo) {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	deleted, err := lockRepo.CleanupRevoked(ctx)
	if err != nil {
		slog.Error("cleanup revoked locks failed", "error", err)
		return
	}
	if deleted > 0 {
		slog.Info("cleaned up revoked lock metadata", "count", deleted)
	}
}


// connectDB 连接数据库
func connectDB(cfg *config.AppConfig) (*pgxpool.Pool, error) {
	dsn := fmt.Sprintf(
		"postgres://%s:%s@%s:%s/%s?sslmode=%s",
		cfg.DBUser, cfg.DBPassword, cfg.DBHost, cfg.DBPort, cfg.DBName, cfg.DBSSLMode,
	)

	poolConfig, err := pgxpool.ParseConfig(dsn)
	if err != nil {
		return nil, fmt.Errorf("parse dsn: %w", err)
	}

	poolConfig.MaxConns = int32(cfg.DBMaxOpenConns)
	poolConfig.MinConns = int32(cfg.DBMaxIdleConns)

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	pool, err := pgxpool.NewWithConfig(ctx, poolConfig)
	if err != nil {
		return nil, fmt.Errorf("create pool: %w", err)
	}

	return pool, nil
}

// setupLogger 配置结构化日志
func setupLogger(env string) {
	opts := &slog.HandlerOptions{}
	if env == "production" {
		opts.Level = slog.LevelInfo
	} else {
		opts.Level = slog.LevelDebug
	}

	var handler slog.Handler
	if env == "production" {
		handler = slog.NewJSONHandler(os.Stdout, opts)
	} else {
		handler = slog.NewTextHandler(os.Stdout, opts)
	}

	slog.SetDefault(slog.New(handler))
}

// gracefulShutdown 优雅关闭服务
func gracefulShutdown(server *http.Server, db *pgxpool.Pool) {
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	sig := <-quit

	slog.Info("shutting down server...", "signal", sig.String())

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := server.Shutdown(ctx); err != nil {
		slog.Error("server forced to shutdown", "error", err)
	}

	// 关闭数据库连接池
	db.Close()

	slog.Info("server stopped")
}
