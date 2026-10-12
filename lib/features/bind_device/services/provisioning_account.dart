/// 配网属于账号，而非某一枚短期登录 token；同账号续期不应中断流程。
bool isProvisioningAccount(String? expectedUserId, String? currentUserId) =>
    expectedUserId != null &&
    expectedUserId.isNotEmpty &&
    expectedUserId == currentUserId;
