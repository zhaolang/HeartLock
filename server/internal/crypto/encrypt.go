package crypto

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"io"

	"github.com/zhaolang/heartlock/internal/model"
)

// KMS 密钥管理服务
type KMS struct {
	masterKey []byte
}

// NewKMS 创建 KMS 实例
// masterKeyHex: 32 字节主密钥的十六进制字符串
func NewKMS(masterKeyHex string) (*KMS, error) {
	if len(masterKeyHex) != 64 {
		return nil, fmt.Errorf("master key must be 32 bytes (64 hex chars), got %d chars", len(masterKeyHex))
	}
	key, err := hex.DecodeString(masterKeyHex)
	if err != nil {
		return nil, fmt.Errorf("invalid master key hex: %w", err)
	}
	return &KMS{masterKey: key}, nil
}

// GenerateDataKey 生成 32 字节随机数据密钥
func (k *KMS) GenerateDataKey() ([]byte, error) {
	key := make([]byte, 32)
	if _, err := io.ReadFull(rand.Reader, key); err != nil {
		return nil, fmt.Errorf("generate data key: %w", err)
	}
	return key, nil
}

// EncryptDataKey 用主密钥加密数据密钥
func (k *KMS) EncryptDataKey(dataKey []byte) ([]byte, error) {
	block, err := aes.NewCipher(k.masterKey)
	if err != nil {
		return nil, fmt.Errorf("encrypt data key: cipher: %w", err)
	}
	aesGCM, err := cipher.NewGCM(block)
	if err != nil {
		return nil, fmt.Errorf("encrypt data key: GCM: %w", err)
	}
	nonce := make([]byte, aesGCM.NonceSize())
	if _, err := io.ReadFull(rand.Reader, nonce); err != nil {
		return nil, fmt.Errorf("encrypt data key: nonce: %w", err)
	}
	return aesGCM.Seal(nonce, nonce, dataKey, nil), nil
}

// DecryptDataKey 用主密钥解密数据密钥
func (k *KMS) DecryptDataKey(encryptedKey []byte) ([]byte, error) {
	block, err := aes.NewCipher(k.masterKey)
	if err != nil {
		return nil, fmt.Errorf("decrypt data key: cipher: %w", err)
	}
	aesGCM, err := cipher.NewGCM(block)
	if err != nil {
		return nil, fmt.Errorf("decrypt data key: GCM: %w", err)
	}
	nonceSize := aesGCM.NonceSize()
	if len(encryptedKey) < nonceSize {
		return nil, fmt.Errorf("decrypt data key: ciphertext too short")
	}
	nonce, ciphertext := encryptedKey[:nonceSize], encryptedKey[nonceSize:]
	return aesGCM.Open(nil, nonce, ciphertext, nil)
}

// EncryptContent AES-256-GCM 加密心锁内容
// 返回: (密文+nonce, nonce, error)
// 简化实现：使用主密钥直接加密（V1 简化，生产环境应使用独立数据密钥）
func (k *KMS) EncryptContent(plaintext string) (ciphertext, nonce []byte, err error) {
	block, err := aes.NewCipher(k.masterKey)
	if err != nil {
		return nil, nil, &model.AppError{Code: 50003, Message: "加密失败", Err: fmt.Errorf("cipher: %w", err)}
	}
	aesGCM, err := cipher.NewGCM(block)
	if err != nil {
		return nil, nil, &model.AppError{Code: 50003, Message: "加密失败", Err: fmt.Errorf("GCM: %w", err)}
	}
	nonce = make([]byte, aesGCM.NonceSize())
	if _, err := io.ReadFull(rand.Reader, nonce); err != nil {
		return nil, nil, &model.AppError{Code: 50003, Message: "加密失败", Err: fmt.Errorf("nonce: %w", err)}
	}
	ciphertext = aesGCM.Seal(nil, nonce, []byte(plaintext), nil)
	return ciphertext, nonce, nil
}

// DecryptContent AES-256-GCM 解密心锁内容
func (k *KMS) DecryptContent(ciphertext, nonce []byte) (string, error) {
	if len(ciphertext) == 0 {
		return "", nil
	}
	block, err := aes.NewCipher(k.masterKey)
	if err != nil {
		return "", &model.AppError{Code: 50003, Message: "解密失败", Err: fmt.Errorf("cipher: %w", err)}
	}
	aesGCM, err := cipher.NewGCM(block)
	if err != nil {
		return "", &model.AppError{Code: 50003, Message: "解密失败", Err: fmt.Errorf("GCM: %w", err)}
	}
	plaintext, err := aesGCM.Open(nil, nonce, ciphertext, nil)
	if err != nil {
		return "", &model.AppError{Code: 50003, Message: "解密失败", Err: fmt.Errorf("open: %w", err)}
	}
	return string(plaintext), nil
}
