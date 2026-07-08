宠物分享功能 - App 端接入文档
概述
宠物分享功能允许用户将自己的宠物分享给其他用户查看和管理。支持两种分享模式：

指定用户分享：通过邮箱指定接收者
匿名分享：生成口令，任何人可凭口令接受
基础信息
Base URL:
测试环境：http://localhost:8002
生产环境：根据实际部署地址
认证方式: 请求头携带 token
Content-Type: application/x-www-form-urlencoded
API 接口列表
1. 发起宠物分享 ⭐
接口: POST /pet/share/add

描述: 宠物拥有者发起分享，生成分享口令

请求头:

Content-Type: application/x-www-form-urlencoded
token: {用户token}
请求参数:

参数名	类型	必填	说明
petId	Long	否*	宠物ID
deviceId	Long	否*	设备ID
mac	String	否*	设备MAC地址
email	String	否	接收者邮箱，为空则匿名分享
type	Integer	否	权限类型：2=管理员，3=成员（默认）
*注：petId、deviceId、mac 三者至少提供一个

成功响应:

{
  "code": 1,
  "tip": "成功",
  "info": {
    "order": "P1215113377705000960_xkz_AB12CD34EF56..."
  }
}
口令格式: P{分享者userId}_{36进制petId}_{加密时间戳}

2. 接受宠物分享
接口: POST /pet/share/accept

请求参数: order (必填)

成功响应: {"code": 1, "tip": "成功"}

3. 拒绝宠物分享
接口: POST /pet/share/refuse

请求参数: shareId 或 order (二选一)

4. 我分享的列表
接口: GET /pet/share/mylist?pageNo=1&pageSize=20

响应示例:

{
  "code": 1,
  "list": [{
    "petShareId": 123456789,
    "petName": "喝天水",
    "toUserEmail": "test5@example.com",
    "state": "pending",
    "para": "P1215...",
    "createTime": "2026-07-03T16:30:00",
    "disableTime": "2026-07-04T16:30:00"
  }],
  "pageTurn": {"totalCount": 10, "pageNo": 1, "totalPage": 1}
}
5. 分享给我的列表
接口: GET /pet/share/withme?pageNo=1&pageSize=20

说明: 仅返回已接受(state=accept)的分享

6. 删除/取消分享
接口: POST /pet/share/del

请求参数: shareId (必填)

业务流程
指定用户分享

匿名分享（二维码）
用户A → POST /pet/share/add (petId)  # 不传email
      ↓
   生成二维码(order)
      ↓
   任何人扫码 → POST /pet/share/accept (order)
错误码
错误码	说明
1	成功
1010	token不存在 → 提示登录
12007	口令过期 → 重新获取
12016	错误的口令
17807	宠物不存在
17819	不是宠物拥有者
17821	已发送过分享邀请
17822	分享记录不存在

### 54.1 POST /pet/info/list — 获取当前用户宠物列表 🔒

> 返回当前登录用户名下所有未删除宠物,按创建时间倒序。**不依赖设备**,未绑定设备的宠物也会返回。无数据时 `info` 为空数组 `[]`。

| 参数 | 值/示例 | 说明 |
|------|---------|------|
| (无) | | 仅需 Header `token`,用户身份从 token 解析 |

**测试结果**: ✅ code=0

**响应:**
```json
{
    "code": 0,
    "info": [
        {
            "createTime": 1783069025440,
            "petId": 9999888877776666,
            "petName": "测试宠物A",
            "userId": 1
        },
        {
            "breed": "Corgi",
            "createTime": 1782280157766,
            "deviceId": 1229405320275623936,
            "petId": 1229638011619844096,
            "petName": "TestPet",
            "sex": "unknown",
            "userId": 1
        }
    ],
    "tip": "响应成功"
}
```

**字段说明** (数组元素,与 `/pet/info/get` 一致):

| 字段 | 类型 | 说明 |
|------|------|------|
| petId | Long | 宠物ID |
| avatar | String | 头像 |
| petName | String | 名称 |
| breed | String | 品种 |
| age | Integer | 年龄 |
| weight | String | 体重 |
| sex | String | 性别: gg / mm / sterilization-gg / sterilization-mm |
| deviceId | Long | 绑定设备ID(未绑定则无此字段) |
| fenceId | Long | 围栏ID |
| fenceStatus | Integer | 1-在围栏 2-不在围栏 |
| param | String | 扩展字段 |
| latitude | String | 纬度(宠物表存储值) |
| longitude | String | 经度(宠物表存储值) |
| createTime | Long | 创建时间(毫秒时间戳) |
| userId | Long | 所属用户ID |

> 注: 值为空的字段不会出现在 JSON 中;`createBy`/`updateBy`/`updateTime`/`deleted` 不返回。

宠物分享成员列表接口文档
接口信息
接口路径: /pet/share/members请求方式: POST接口描述: 查询指定宠物的分享成员列表,包括宠物主人和已接受分享的成员权限要求: 仅宠物 owner 或已接受分享的成员可查询
请求参数
Headers

参数名类型必填说明

  token    String    是    用户登录 token,格式: ipet_aws_user_info_hash:_<ttl>_<hash>  
  Content-Type    String    是    application/x-www-form-urlencoded  

Body 参数

参数名类型必填说明

  petId    Long    是    宠物 ID  

返回参数
成功响应 (code=0)
{
  "code": 0,
  "info": {
    "owner": {
      "userId": 1215113377705000960,
      "account": "18616717926@qq.com",
      "name": "宠友7926",
      "role": "owner"
    },
    "members": [
      {
        "userId": 1215184034045075456,
        "account": "user@example.com",
        "name": "张三",
        "permission": 3,
        "shareId": 1219527580735262721,
        "joinTime": 1779869643201
      }
    ],
    "totalCount": 2
  },
  "tip": "响应成功"
}

字段说明
owner 对象

字段名类型说明

  userId    Long    用户 ID  
  account    String    账号(邮箱)  
  name    String    用户昵称  
  role    String    角色标识,固定值 "owner"  

members 数组

字段名类型说明

  userId    Long    成员用户 ID  
  account    String    成员账号(邮箱)  
  name    String    成员昵称  
  permission    Integer    权限类型: 3=成员  
  shareId    Long    分享记录 ID  
  joinTime    Long    加入时间(时间戳,毫秒)  

根级别字段

字段名类型说明

  totalCount    Integer    总成员数 (owner + members 数量)  

错误码

codetip说明

  0    响应成功    请求成功  
  1003    参数错误    petId 参数缺失或为空  
  1021    宠物不存在    宠物已删除或不存在  
  17804    无权限操作    当前用户既非 owner 也非已接受分享的成员  
  1023    用户不存在    owner 用户信息异常  