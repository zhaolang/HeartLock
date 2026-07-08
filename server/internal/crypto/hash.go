package crypto

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"

	"golang.org/x/crypto/bcrypt"
)

// HashPhone 对手机号进行 bcrypt 加盐哈希
// 返回: (hash, salt, error)
// cost=12 提供约 250ms 的计算延迟，足够抵抗暴力破解
func HashPhone(phone string) (hash, salt string, err error) {
	// bcrypt 将 salt 内嵌在 hash 字符串中
	// 因此 hash 本身即包含 salt，无需单独存储 salt 字段
	// 但为了显式记录和未来迁移，我们仍将 salt 单独提取存储
	// salt is embedded in bcrypt hash
	// 使用 GenerateFromPassword 自动生成随机 salt
	hashedBytes, err := bcrypt.GenerateFromPassword([]byte(phone), 12)
	if err != nil {
		return "", "", fmt.Errorf("hash phone: %w", err)
	}
	hash = string(hashedBytes)
	// bcrypt hash 格式: $2a$12$<22 chars salt><31 chars hash>
	// salt 是前 22 个 base64 字符
	if len(hash) >= 29 {
		salt = hash[7:29] // 提取 salt 部分
	} else {
		salt = ""
	}
	return hash, salt, nil
}

// VerifyPhone 验证手机号与哈希是否匹配
func VerifyPhone(phone, hash string) bool {
	err := bcrypt.CompareHashAndPassword([]byte(hash), []byte(phone))
	return err == nil
}

// HashPhoneSHA256 对手机号进行 SHA-256 哈希（确定性，用于匹配检测）
func HashPhoneSHA256(phone string) string {
	h := sha256.Sum256([]byte(phone))
	return hex.EncodeToString(h[:])
}

// VerifyPhoneSHA256 验证手机号与 SHA-256 哈希是否匹配
func VerifyPhoneSHA256(phone, hash string) bool {
	return HashPhoneSHA256(phone) == hash
}
