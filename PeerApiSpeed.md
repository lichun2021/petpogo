### 15.1 前进（50%速度）

**请求参数:**
```
mac=ipet-esp32-Device-02
data={"motor_0":{"direction":1,"speed":50},"motor_1":{"direction":1,"speed":50}}
```

**curl 示例:**
```bash
curl -s http://localhost:8002/device/shadow/update -X POST \
  -H "token: $TOKEN" \
  --data-urlencode "mac=ipet-esp32-Device-02" \
  --data-urlencode 'data={"motor_0":{"direction":1,"speed":50},"motor_1":{"direction":1,"speed":50}}'
```

**响应:**
```json
{"code":0,"tip":"响应成功"}
```

**预期效果:** 两轮同时正转，速度 50%

---

### 15.2 后退（50%速度）

**请求参数:**
```
mac=ipet-esp32-Device-02
data={"motor_0":{"direction":0,"speed":50},"motor_1":{"direction":0,"speed":50}}
```

**curl 示例:**
```bash
curl -s http://localhost:8002/device/shadow/update -X POST \
  -H "token: $TOKEN" \
  --data-urlencode "mac=ipet-esp32-Device-02" \
  --data-urlencode 'data={"motor_0":{"direction":0,"speed":50},"motor_1":{"direction":0,"speed":50}}'
```

**响应:**
```json
{"code":0,"tip":"响应成功"}
```

**预期效果:** 两轮同时反转，速度 50%

---

### 15.3 加速（80%速度）

**请求参数:**
```
mac=ipet-esp32-Device-02
data={"motor_0":{"direction":1,"speed":80},"motor_1":{"direction":1,"speed":80}}
```

**curl 示例:**
```bash
curl -s http://localhost:8002/device/shadow/update -X POST \
  -H "token: $TOKEN" \
  --data-urlencode "mac=ipet-esp32-Device-02" \
  --data-urlencode 'data={"motor_0":{"direction":1,"speed":80},"motor_1":{"direction":1,"speed":80}}'
```

**响应:**
```json
{"code":0,"tip":"响应成功"}
```

**预期效果:** 两轮正转加速到 80%

---

### 15.4 减速（20%速度）

**请求参数:**
```
mac=ipet-esp32-Device-02
data={"motor_0":{"direction":1,"speed":20},"motor_1":{"direction":1,"speed":20}}
```

**curl 示例:**
```bash
curl -s http://localhost:8002/device/shadow/update -X POST \
  -H "token: $TOKEN" \
  --data-urlencode "mac=ipet-esp32-Device-02" \
  --data-urlencode 'data={"motor_0":{"direction":1,"speed":20},"motor_1":{"direction":1,"speed":20}}'
```

**响应:**
```json
{"code":0,"tip":"响应成功"}
```

**预期效果:** 两轮正转减速到 20%

---

### 15.5 左转（左轮停，右轮转）

**请求参数:**
```
mac=ipet-esp32-Device-02
data={"motor_0":{"direction":1,"speed":0},"motor_1":{"direction":1,"speed":50}}
```

**curl 示例:**
```bash
curl -s http://localhost:8002/device/shadow/update -X POST \
  -H "token: $TOKEN" \
  --data-urlencode "mac=ipet-esp32-Device-02" \
  --data-urlencode 'data={"motor_0":{"direction":1,"speed":0},"motor_1":{"direction":1,"speed":50}}'
```

**响应:**
```json
{"code":0,"tip":"响应成功"}
```

**预期效果:** motor_0（左轮）停止，motor_1（右轮）正转 50%，车身向左转

---

### 15.6 右转（左轮转，右轮停）

**请求参数:**
```
mac=ipet-esp32-Device-02
data={"motor_0":{"direction":1,"speed":50},"motor_1":{"direction":1,"speed":0}}
```

**curl 示例:**
```bash
curl -s http://localhost:8002/device/shadow/update -X POST \
  -H "token: $TOKEN" \
  --data-urlencode "mac=ipet-esp32-Device-02" \
  --data-urlencode 'data={"motor_0":{"direction":1,"speed":50},"motor_1":{"direction":1,"speed":0}}'
```

**响应:**
```json
{"code":0,"tip":"响应成功"}
```

**预期效果:** motor_0（左轮）正转 50%，motor_1（右轮）停止，车身向右转

---

### 15.7 停止

**请求参数:**
```
mac=ipet-esp32-Device-02
data={"motor_0":{"direction":0,"speed":0},"motor_1":{"direction":0,"speed":0}}
```

**curl 示例:**
```bash
curl -s http://localhost:8002/device/shadow/update -X POST \
  -H "token: $TOKEN" \
  --data-urlencode "mac=ipet-esp32-Device-02" \
  --data-urlencode 'data={"motor_0":{"direction":0,"speed":0},"motor_1":{"direction":0,"speed":0}}'
```