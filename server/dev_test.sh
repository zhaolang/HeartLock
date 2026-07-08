#!/bin/bash
# HeartLock API 开发测试脚本
# 自动运行完整的 API 测试套件

BASE_URL="${BASE_URL:-http://localhost:8080/v1}"
PASS=0
FAIL=0

pass() { PASS=$((PASS+1)); echo "  ✅ PASS"; }
fail() { FAIL=$((FAIL+1)); echo "  ❌ FAIL: $1"; }

echo ""
echo "============================================"
echo "  HeartLock API Development Test Suite"
echo "  Base URL: $BASE_URL"
echo "============================================"

# ==========================================
# 1. 健康检查
echo ""
echo "--- 1. Health Check ---"
HEALTH=$(curl -s http://localhost:8080/health 2>/dev/null)
STATUS=$(echo "$HEALTH" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('status',''))" 2>/dev/null)
echo "  Status: $STATUS"
[ "$STATUS" = "healthy" ] && pass || fail "Health check failed"

# ==========================================
# 2-3. 注册测试用户
echo ""
echo "--- 2. Register User A (13800138001) ---"
REG_A=$(curl -s -X POST "$BASE_URL/auth/register" \
  -H "Content-Type: application/json" \
  -d '{"huawei_credentials":"dev_test_a","phone_number":"13800138001"}')
TOKEN_A=$(echo "$REG_A" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('token',''))" 2>/dev/null)
[ -n "$TOKEN_A" ] && pass || fail "Register A: $(echo $REG_A | head -c 100)"

echo "--- 3. Register User B (13800138002) ---"
REG_B=$(curl -s -X POST "$BASE_URL/auth/register" \
  -H "Content-Type: application/json" \
  -d '{"huawei_credentials":"dev_test_b","phone_number":"13800138002"}')
TOKEN_B=$(echo "$REG_B" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('token',''))" 2>/dev/null)
[ -n "$TOKEN_B" ] && pass || fail "Register B"

# ==========================================
# 4-5. 登录
echo ""
echo "--- 4. Login A ---"
LOGIN_A=$(curl -s -X POST "$BASE_URL/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"huawei_credentials":"dev_test_a"}')
TOKEN_A=$(echo "$LOGIN_A" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('token',''))" 2>/dev/null)
[ -n "$TOKEN_A" ] && pass || fail "Login A"

echo "--- 5. Login B ---"
LOGIN_B=$(curl -s -X POST "$BASE_URL/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"huawei_credentials":"dev_test_b"}')
TOKEN_B=$(echo "$LOGIN_B" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('token',''))" 2>/dev/null)
[ -n "$TOKEN_B" ] && pass || fail "Login B"

# ==========================================
# 6. A -> B 心锁（应 WAITING）
echo ""
echo "--- 6. A lock -> B (expect WAITING) ---"
LOCK_A=$(curl -s -X POST "$BASE_URL/heart-locks" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN_A" \
  -d '{"target_phone":"13800138002","content":"当星光黯淡，你是唯一的光。"}')
LOCK_A_ID=$(echo "$LOCK_A" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('id',''))" 2>/dev/null)
LOCK_A_STATUS=$(echo "$LOCK_A" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('status',''))" 2>/dev/null)
echo "  Status: $LOCK_A_STATUS"
[ "$LOCK_A_STATUS" = "WAITING" ] && pass || fail "Expected WAITING"

# ==========================================
# 7. B -> A 心锁（应 MATCHED，触发匹配）
echo ""
echo "--- 7. B lock -> A (expect MATCHED) ---"
LOCK_B=$(curl -s -X POST "$BASE_URL/heart-locks" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN_B" \
  -d '{"target_phone":"13800138001","content":"竟然是你，一直是你。"}')
LOCK_B_STATUS=$(echo "$LOCK_B" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('status',''))" 2>/dev/null)
LOCK_B_MATCHED=$(echo "$LOCK_B" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('matched',False))" 2>/dev/null)
LOCK_B_THEIR=$(echo "$LOCK_B" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('their_words',''))" 2>/dev/null)
echo "  Status: $LOCK_B_STATUS, Matched: $LOCK_B_MATCHED"
echo "  First words: $LOCK_B_THEIR"
[ "$LOCK_B_STATUS" = "MATCHED" ] && [ "$LOCK_B_MATCHED" = "True" ] && [ -n "$LOCK_B_THEIR" ] && pass || fail "Match failed"

# ==========================================
# 8. 检查 A 的心锁详情（也应 MATCHED）
echo ""
echo "--- 8. A lock detail (expect MATCHED) ---"
DETAIL_A=$(curl -s -X GET "$BASE_URL/heart-locks/$LOCK_A_ID" \
  -H "Authorization: Bearer $TOKEN_A")
DET_STATUS=$(echo "$DETAIL_A" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('status',''))" 2>/dev/null)
DET_MY=$(echo "$DETAIL_A" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('my_words',''))" 2>/dev/null)
DET_THEIR=$(echo "$DETAIL_A" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('their_words',''))" 2>/dev/null)
echo "  Status: $DET_STATUS"
echo "  My words: $DET_MY"
echo "  Their words: $DET_THEIR"
[ "$DET_STATUS" = "MATCHED" ] && [ -n "$DET_MY" ] && [ -n "$DET_THEIR" ] && pass || fail "Detail not MATCHED"

# ==========================================
# 9. 错误测试
echo ""
echo "--- 9. Duplicate lock (expect 40011) ---"
DUP=$(curl -s -X POST "$BASE_URL/heart-locks" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN_A" \
  -d '{"target_phone":"13800138002","content":"再试一次"}')
DUP_CODE=$(echo "$DUP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('code',-1))" 2>/dev/null)
echo "  Code: $DUP_CODE"
[ "$DUP_CODE" = "40011" ] && pass || fail "Duplicate failed"

echo "--- 10. Self lock (expect 40012) ---"
SELF=$(curl -s -X POST "$BASE_URL/heart-locks" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN_A" \
  -d '{"target_phone":"13800138001","content":"喜欢自己"}')
SELF_CODE=$(echo "$SELF" | python3 -c "import sys,json; print(json.load(sys.stdin).get('code',-1))" 2>/dev/null)
echo "  Code: $SELF_CODE"
[ "$SELF_CODE" = "40012" ] && pass || fail "Self lock failed"

echo "--- 11. Unauthorized (expect 40002) ---"
UNAUTH=$(curl -s -X GET "$BASE_URL/heart-locks")
UNAUTH_CODE=$(echo "$UNAUTH" | python3 -c "import sys,json; print(json.load(sys.stdin).get('code',-1))" 2>/dev/null)
echo "  Code: $UNAUTH_CODE"
[ "$UNAUTH_CODE" = "40002" ] && pass || fail "Auth check failed"

# ==========================================
# 12. Push Token
echo ""
echo "--- 12. Push Token ---"
PUSH=$(curl -s -X POST "$BASE_URL/push/token" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN_A" \
  -d '{"push_token":"test_token","device_id":"test_device"}')
PUSH_CODE=$(echo "$PUSH" | python3 -c "import sys,json; print(json.load(sys.stdin).get('code',-1))" 2>/dev/null)
echo "  Register: $PUSH_CODE"
[ "$PUSH_CODE" = "0" ] && pass || fail "Push register"

# ==========================================
# 13. 心锁上限测试
echo ""
echo "--- 13. Lock limit test ---"
REG_C=$(curl -s -X POST "$BASE_URL/auth/register" \
  -H "Content-Type: application/json" \
  -d '{"huawei_credentials":"dev_test_c","phone_number":"13800138003"}')
TOKEN_C=$(echo "$REG_C" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('token',''))" 2>/dev/null)
for i in 04 05 06; do
  curl -s -X POST "$BASE_URL/heart-locks" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN_C" \
    -d "{\"target_phone\":\"13800138$i\",\"content\":\"Lock $i\"}" > /dev/null
done
LIMIT=$(curl -s -X POST "$BASE_URL/heart-locks" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN_C" \
  -d '{"target_phone":"13800138007","content":"Should fail"}')
LIMIT_CODE=$(echo "$LIMIT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('code',-1))" 2>/dev/null)
echo "  4th lock code: $LIMIT_CODE"
[ "$LIMIT_CODE" = "40010" ] && pass || fail "Limit check failed"

# ==========================================
# 14-15. Revoke & Destroy
echo ""
echo "--- 14. Revoke ---"
C_LOCKS=$(curl -s -X GET "$BASE_URL/heart-locks" \
  -H "Authorization: Bearer $TOKEN_C")
C_LOCK_ID=$(echo "$C_LOCKS" | python3 -c "import sys,json; d=json.load(sys.stdin); ls=d.get('data',{}).get('locks',[{}]); print(ls[0]['id'] if ls else '')" 2>/dev/null)
if [ -n "$C_LOCK_ID" ]; then
  REV=$(curl -s -X PATCH "$BASE_URL/heart-locks/$C_LOCK_ID/revoke" \
    -H "Authorization: Bearer $TOKEN_C")
  REV_STATUS=$(echo "$REV" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('status',''))" 2>/dev/null)
  echo "  Revoke status: $REV_STATUS"
  [ "$REV_STATUS" = "REVOKED" ] && pass || fail "Revoke failed"
  
  echo "--- 15. Destroy ---"
  DES=$(curl -s -X DELETE "$BASE_URL/heart-locks/$C_LOCK_ID" \
    -H "Authorization: Bearer $TOKEN_C")
  DES_STATUS=$(echo "$DES" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('status',''))" 2>/dev/null)
  echo "  Destroy status: $DES_STATUS"
  [ "$DES_STATUS" = "DESTROYED" ] && pass || fail "Destroy failed"
fi

# ==========================================
echo ""
echo "============================================"
echo "  Tests: $((PASS+FAIL)) total, $PASS passed, $FAIL failed"
echo "============================================"

[ "$FAIL" -eq 0 ] && echo "All tests passed!" || echo "Some tests failed."
exit $FAIL
