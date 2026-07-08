package middleware

import (
	"net/http"
	"sync"
	"time"

	"github.com/zhaolang/heartlock/internal/dto"
	"golang.org/x/time/rate"
)

// IPRateLimiter IP 粒度的限流器
type IPRateLimiter struct {
	mu       sync.RWMutex
	clients  map[string]*rate.Limiter
	rate     rate.Limit
	burst    int
	cleanupInterval time.Duration
}

// NewIPRateLimiter 创建 IP 限流器
func NewIPRateLimiter(r rate.Limit, burst int) *IPRateLimiter {
	rl := &IPRateLimiter{
		clients:  make(map[string]*rate.Limiter),
		rate:     r,
		burst:    burst,
		cleanupInterval: time.Hour,
	}
	go rl.cleanup()
	return rl
}

func (rl *IPRateLimiter) getLimiter(ip string) *rate.Limiter {
	rl.mu.RLock()
	limiter, exists := rl.clients[ip]
	rl.mu.RUnlock()
	if exists {
		return limiter
	}
	rl.mu.Lock()
	defer rl.mu.Unlock()
	// 双重检查
	limiter, exists = rl.clients[ip]
	if exists {
		return limiter
	}
	limiter = rate.NewLimiter(rl.rate, rl.burst)
	rl.clients[ip] = limiter
	return limiter
}

func (rl *IPRateLimiter) cleanup() {
	ticker := time.NewTicker(rl.cleanupInterval)
	defer ticker.Stop()
	for range ticker.C {
		rl.mu.Lock()
		rl.clients = make(map[string]*rate.Limiter)
		rl.mu.Unlock()
	}
}

// RateLimit 全局限流中间件（IP 粒度，60 req/min）
func RateLimit(next http.Handler) http.Handler {
	limiter := NewIPRateLimiter(rate.Every(time.Minute/60), 60)
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		ip := r.RemoteAddr
		if forwarded := r.Header.Get("X-Forwarded-For"); forwarded != "" {
			ip = forwarded
		}
		if !limiter.getLimiter(ip).Allow() {
			WriteJSON(w, http.StatusTooManyRequests, dto.APIResponse{
				Code:      40001,
				Message:   "请求过于频繁，请稍后重试",
				RequestID: GetRequestID(r.Context()),
			})
			return
		}
		next.ServeHTTP(w, r)
	})
}

// CreateLockRateLimit 创建心锁限流中间件（每用户每小时 10 次）
// 简化实现：基于 IP 进行限流
func CreateLockRateLimit(next http.Handler) http.Handler {
	limiter := NewIPRateLimiter(rate.Every(time.Hour/10), 10)
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		ip := r.RemoteAddr
		if forwarded := r.Header.Get("X-Forwarded-For"); forwarded != "" {
			ip = forwarded
		}
		if !limiter.getLimiter(ip).Allow() {
			WriteJSON(w, http.StatusTooManyRequests, dto.APIResponse{
				Code:      40001,
				Message:   "请求过于频繁，请稍后重试",
				RequestID: GetRequestID(r.Context()),
			})
			return
		}
		next.ServeHTTP(w, r)
	})
}

// LoginRateLimit 登录限流中间件（每 IP 每小时 20 次）
func LoginRateLimit(next http.Handler) http.Handler {
	limiter := NewIPRateLimiter(rate.Every(time.Hour/20), 20)
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		ip := r.RemoteAddr
		if forwarded := r.Header.Get("X-Forwarded-For"); forwarded != "" {
			ip = forwarded
		}
		if !limiter.getLimiter(ip).Allow() {
			WriteJSON(w, http.StatusTooManyRequests, dto.APIResponse{
				Code:      40001,
				Message:   "请求过于频繁，请稍后重试",
				RequestID: GetRequestID(r.Context()),
			})
			return
		}
		next.ServeHTTP(w, r)
	})
}
