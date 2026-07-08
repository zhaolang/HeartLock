package crypto

import (
	"fmt"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

// Claims JWT 声明
type Claims struct {
	UserID    string `json:"user_id"`
	PhoneHash string `json:"phone_hash,omitempty"`
	jwt.RegisteredClaims
}

// TokenManager JWT 令牌管理器
type TokenManager struct {
	secret      []byte
	expiryHours int
}

// NewTokenManager 创建令牌管理器
func NewTokenManager(secret string, expiryHours int) *TokenManager {
	return &TokenManager{
		secret:      []byte(secret),
		expiryHours: expiryHours,
	}
}

// Generate 签发 JWT
func (tm *TokenManager) Generate(userID string) (string, error) {
	now := time.Now()
	claims := &Claims{
		UserID: userID,
		RegisteredClaims: jwt.RegisteredClaims{
			IssuedAt:  jwt.NewNumericDate(now),
			ExpiresAt: jwt.NewNumericDate(now.Add(time.Duration(tm.expiryHours) * time.Hour)),
			Issuer:    "heartlock",
		},
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	tokenString, err := token.SignedString(tm.secret)
	if err != nil {
		return "", fmt.Errorf("generate token: %w", err)
	}
	return tokenString, nil
}

// Validate 验证并解析 JWT
func (tm *TokenManager) Validate(tokenString string) (*Claims, error) {
	token, err := jwt.ParseWithClaims(tokenString, &Claims{}, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
		}
		return tm.secret, nil
	})
	if err != nil {
		return nil, fmt.Errorf("validate token: %w", err)
	}
	claims, ok := token.Claims.(*Claims)
	if !ok || !token.Valid {
		return nil, fmt.Errorf("invalid token claims")
	}
	return claims, nil
}
