package service

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"time"

	"github.com/zhaolang/heartlock/internal/repository"
)

// PushService 推送业务服务
type PushService struct {
	pushRepo    *repository.PushRepo
	pushAppID   string
	pushSecret  string
	httpClient  *http.Client
}

// NewPushService 创建推送服务
func NewPushService(pushRepo *repository.PushRepo, pushAppID, pushSecret string) *PushService {
	return &PushService{
		pushRepo:  pushRepo,
		pushAppID: pushAppID,
		pushSecret: pushSecret,
		httpClient: &http.Client{
			Timeout: 10 * time.Second,
		},
	}
}

// RegisterToken 注册推送 Token
func (s *PushService) RegisterToken(ctx context.Context, userID, pushToken, deviceID string) error {
	_, err := s.pushRepo.Create(ctx, userID, pushToken, deviceID)
	return err
}

// DeleteToken 删除推送 Token
func (s *PushService) DeleteToken(ctx context.Context, userID, deviceID string) error {
	return s.pushRepo.DeleteByDevice(ctx, userID, deviceID)
}

// SendMatchNotification 发送匹配成功推送通知
// RULE-040: 仅在匹配成功时发送
// RULE-041: 内容仅为"心锁已打开"+ 对方第一句话（前 50 字）
func (s *PushService) SendMatchNotification(ctx context.Context, userID1, userID2, theirWords string) {
	// 为双方各自发送通知
	s.sendToUser(ctx, userID1, theirWords)
	s.sendToUser(ctx, userID2, theirWords)
}

// sendToUser 向指定用户发送推送
func (s *PushService) sendToUser(ctx context.Context, userID, theirWords string) {
	// 获取用户的推送 Token
	tokens, err := s.pushRepo.FindByUserID(ctx, userID)
	if err != nil {
		slog.Error("find push tokens failed", "error", err, "user_id", userID)
		return
	}

	if len(tokens) == 0 {
		slog.Warn("no push tokens found for user", "user_id", userID)
		return
	}

	// 提取 Token 列表
	tokenList := make([]string, len(tokens))
	for i, t := range tokens {
		tokenList[i] = t.PushToken
	}

	// 构建推送内容
	title := "心锁已打开"
	body := truncateText(theirWords, 50)
	if body == "" {
		body = "你们互相喜欢"
	}

	pushReq := HuaweiPushRequest{
		ValidateOnly: false,
		Message: HuaweiMessage{
			Token: tokenList,
			Notification: &HuaweiNotification{
				Title: title,
				Body:  body,
			},
			Data: `{"type":"match","version":"1"}`,
		},
	}

	// 发送推送（异步非阻塞）
	if err := s.callHuaweiPushAPI(ctx, pushReq); err != nil {
		slog.Error("send push notification failed", "error", err, "user_id", userID)
	}
}

// callHuaweiPushAPI 调用华为推送 API
func (s *PushService) callHuaweiPushAPI(ctx context.Context, req HuaweiPushRequest) error {
	// 如果没有配置推送凭据，跳过（开发模式）
	if s.pushAppID == "" || s.pushSecret == "" {
		slog.Info("push service not configured, skipping push notification")
		return nil
	}

	// 获取华为推送 Access Token
	accessToken, err := s.getHuaweiAccessToken(ctx)
	if err != nil {
		return fmt.Errorf("get huawei access token: %w", err)
	}

	// 发送推送
	pushURL := fmt.Sprintf("https://push-api.cloud.huawei.com/v1/%s/messages:send", s.pushAppID)
	payload, err := json.Marshal(req)
	if err != nil {
		return fmt.Errorf("marshal push request: %w", err)
	}

	httpReq, err := http.NewRequestWithContext(ctx, "POST", pushURL, bytes.NewReader(payload))
	if err != nil {
		return fmt.Errorf("create push request: %w", err)
	}
	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("Authorization", "Bearer "+accessToken)

	resp, err := s.httpClient.Do(httpReq)
	if err != nil {
		return fmt.Errorf("huawei push api call: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("huawei push api returned status %d", resp.StatusCode)
	}

	return nil
}

// getHuaweiAccessToken 获取华为推送 Access Token
func (s *PushService) getHuaweiAccessToken(ctx context.Context) (string, error) {
	// POST https://oauth-login.cloud.huawei.com/oauth2/v3/token
	tokenURL := "https://oauth-login.cloud.huawei.com/oauth2/v3/token"
	payload := fmt.Sprintf(
		"grant_type=client_credentials&client_id=%s&client_secret=%s",
		s.pushAppID, s.pushSecret,
	)

	req, err := http.NewRequestWithContext(ctx, "POST", tokenURL, bytes.NewReader([]byte(payload)))
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	var tokenResp struct {
		AccessToken string `json:"access_token"`
		ExpiresIn   int    `json:"expires_in"`
		Error       string `json:"error"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&tokenResp); err != nil {
		return "", err
	}

	if tokenResp.Error != "" {
		return "", fmt.Errorf("huawei auth error: %s", tokenResp.Error)
	}

	return tokenResp.AccessToken, nil
}

// ---------- 华为推送请求结构体 ----------

type HuaweiPushRequest struct {
	ValidateOnly bool           `json:"validate_only"`
	Message      HuaweiMessage  `json:"message"`
}

type HuaweiMessage struct {
	Token        []string                `json:"token"`
	Data         string                  `json:"data"`
	Notification *HuaweiNotification     `json:"notification,omitempty"`
	Android      *HuaweiAndroidConfig    `json:"android,omitempty"`
}

type HuaweiNotification struct {
	Title string `json:"title"`
	Body  string `json:"body"`
}

type HuaweiAndroidConfig struct {
	FastAppTargetType int `json:"fast_app_target_type"`
}
