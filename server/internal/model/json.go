package model

import (
	"encoding/json"
	"io"
	"log/slog"
)

// WriteJSON 写入 JSON 到 writer
func WriteJSON(w io.Writer, data interface{}) error {
	payload, err := json.Marshal(data)
	if err != nil {
		slog.Error("marshal json failed", "error", err)
		return err
	}
	_, err = w.Write(payload)
	return err
}

// ReadJSON 从 reader 读取并解析 JSON
func ReadJSON(r io.Reader, v interface{}) error {
	decoder := json.NewDecoder(r)
	return decoder.Decode(v)
}
