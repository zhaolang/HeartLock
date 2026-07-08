package config

import (
	"github.com/caarlos0/env/v11"
)

// AppConfig 应用配置，从环境变量加载
type AppConfig struct {
	// 应用
	Port    string `env:"APP_PORT"     envDefault:"8080"`
	Env     string `env:"APP_ENV"      envDefault:"development"`
	Version string `env:"APP_VERSION"  envDefault:"1.0.0"`

	// 数据库
	DBHost         string `env:"DB_HOST"          envDefault:"localhost"`
	DBPort         string `env:"DB_PORT"          envDefault:"5432"`
	DBUser         string `env:"DB_USER"          envDefault:"heartlock"`
	DBPassword     string `env:"DB_PASSWORD"      envDefault:"heartlock_dev"`
	DBName         string `env:"DB_NAME"          envDefault:"heartlock"`
	DBSSLMode      string `env:"DB_SSLMODE"       envDefault:"disable"`
	DBMaxOpenConns int    `env:"DB_MAX_OPEN_CONNS"   envDefault:"25"`
	DBMaxIdleConns int    `env:"DB_MAX_IDLE_CONNS"   envDefault:"10"`

	// JWT
	JWTSecret      string `env:"JWT_SECRET"       envDefault:"dev-secret-change-in-production"`
	JWTExpiryHours int    `env:"JWT_EXPIRY_HOURS" envDefault:"720"`

	// 主密钥（用于加密数据密钥，HEX 32字节）
	MasterKey string `env:"MASTER_KEY" envDefault:"0000000000000000000000000000000000000000000000000000000000000000"`

	// 华为推送
	HuaweiPushAppID     string `env:"HUAWEI_PUSH_APP_ID"`
	HuaweiPushAppSecret string `env:"HUAWEI_PUSH_APP_SECRET"`

	// 日志
	LogLevel string `env:"LOG_LEVEL" envDefault:"info"`
}

// Load 加载配置
func Load() (*AppConfig, error) {
	cfg := &AppConfig{}
	if err := env.Parse(cfg); err != nil {
		return nil, err
	}
	return cfg, nil
}
