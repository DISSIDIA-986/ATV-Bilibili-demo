# 部署应用到 Apple TV 4K 操作指南

本文档记录了如何使用免费 Apple ID 将未签名的应用部署到 Apple TV 4K 的完整步骤。

## 前置条件

- ✅ 已安装 Xcode
- ✅ 有一个免费的 Apple ID
- ✅ Apple TV 4K 与 Mac 在同一 Wi-Fi 网络
- ✅ Xcode 项目已配置好

## 快速部署（推荐）

1. Xcode 登录你的 Apple ID（Personal Team 即可）。路径：Xcode → Settings → Accounts，确认无警告。
2. 打开 `BilibiliLive.xcodeproj`，Target `BilibiliLive` → Signing & Capabilities：勾选 Automatically manage signing，Team 选你的账号，Bundle Identifier 设为你自己的（例如 `com.<你的前缀>.BilibiliLive`）。工程默认是占位的 Team/Bundle，需要你在本机覆盖。
3. 运行部署脚本（已在仓库根目录）：
   ```bash
   TEAM_ID=<你的TeamID> \
   BUNDLE_ID=com.<你的前缀>.BilibiliLive \
   DEVICE_ID=<Apple TV 的设备ID> \
   SKIP_CLEAN=1 \
   bash deploy-to-appletv.sh
   ```
   - `TEAM_ID` 可在 Xcode → Accounts 里看到 10 位 ID（例：`X3RG65K69M`）。
   - `DEVICE_ID` 用 `xcrun xcdevice list` 查询（例：`00008110-00024C9C21DA801E`）。
   - 如已在工程中选好 Team/Bundle，可省略 `TEAM_ID`/`BUNDLE_ID`。

> 与旧版说明不同：无需手动编辑 `project.pbxproj`，脚本会沿用 Xcode 的自动签名，必要时可用环境变量覆盖。

---

## 一、配置项目签名（手动方式，若不使用脚本覆盖）

### 1.2 检查可用的开发者证书

```bash
# 查看系统中的开发者证书
security find-identity -v -p codesigning | grep "Apple Development"
```

输出示例：
```
1) F03142F3A572C2EE8B4F0F4E1949C26500CA7149 "Apple Development: your-email@gmail.com (X3RG65K69M)"
```

### 1.3 在 Xcode 中配置 Team

1. 打开 Xcode 项目：
```bash
open -a Xcode BilibiliLive.xcodeproj
```

2. 在 Xcode 中：
   - 点击左侧的项目名称
   - 选择 Target
   - 点击 **Signing & Capabilities** 标签
   - 勾选 **Automatically manage signing**
   - 在 **Team** 下拉菜单中选择你的 Apple ID
   - Xcode 会自动生成开发证书和配置文件

## 二、配对 Apple TV 设备

### 2.1 在 Apple TV 上启用远程访问

在 **Apple TV 4K** 上操作：
1. 设置 > 遥控器与设备 > 远程App与设备
2. 确保已启用
3. 如果有"开发者模式"选项（设置 > 通用 > 隐私与安全性），也要启用

### 2.2 获取 Apple TV 的 IP 地址

在 Apple TV 上：
- 设置 > 网络 > [你的 Wi-Fi 网络名称]
- 记下 IP 地址（例如：192.168.1.119）

### 2.3 验证网络连通性

```bash
# 测试与 Apple TV 的网络连接
ping -c 3 192.168.1.119
```

输出示例：
```
PING 192.168.1.119 (192.168.1.119): 56 data bytes
64 bytes from 192.168.1.119: icmp_seq=0 ttl=64 time=11.144 ms
...
3 packets transmitted, 3 packets received, 0.0% packet loss
```

### 2.4 在 Xcode 中配对设备

**方法 A：通过 Xcode GUI（推荐）**

1. 在 Xcode 菜单栏：**Window > Devices and Simulators** (或 `Cmd+Shift+2`)
2. 确保在 **Devices** 标签
3. 点击左下角的 **+** 按钮
4. 选择网络上发现的 Apple TV 设备
5. 点击 **Pair**
6. 在 Apple TV 上会显示配对码，输入到 Xcode 中
7. 配对成功后，设备会显示在列表中

**方法 B：检查已配对的设备**

```bash
# 列出所有已连接的设备
xcrun devicectl list devices

# 或使用旧的工具
instruments -s devices 2>&1 | grep -i "tv"
```

### 2.5 获取设备 ID

配对成功后，记下设备 ID，格式类似：
```
{ platform:tvOS, arch:arm64, id:00008110-00024C9C21DA801E, name:Jason room }
```

其中 `00008110-00024C9C21DA801E` 就是设备 ID。

## 三、构建和部署应用

### 3.1 清理构建缓存（可选但推荐）

```bash
# 清理旧的构建数据
rm -rf ~/Library/Developer/Xcode/DerivedData/BilibiliLive-*
```

### 3.2 构建应用

使用设备 ID 构建应用（替换为你的设备 ID）：

```bash
xcodebuild -project BilibiliLive.xcodeproj \
  -scheme BilibiliLive \
  -destination 'platform=tvOS,id=00008110-00024C9C21DA801E' \
  -allowProvisioningUpdates \
  clean build
```

**参数说明：**
- `-project`: 项目文件路径
- `-scheme`: 构建方案（通常与项目名相同）
- `-destination`: 目标设备（使用设备 ID）
- `-allowProvisioningUpdates`: 允许自动更新配置文件
- `clean build`: 先清理再构建

**预期输出：**
构建过程会显示编译进度，最后看到：
```
Signing Identity:     "Apple Development: your-email@gmail.com (X3RG65K69M)"
** BUILD SUCCEEDED **
```

### 3.3 安装应用到 Apple TV

```bash
# 使用 devicectl 工具安装（推荐，适用于较新的 Xcode）
xcrun devicectl device install app \
  --device 00008110-00024C9C21DA801E \
  ~/Library/Developer/Xcode/DerivedData/BilibiliLive-*/Build/Products/Debug-appletvos/BilibiliLive.app
```

**预期输出：**
```
Acquired tunnel connection to device.
Enabling developer disk image services.
Acquired usage assertion.
App installed:
• bundleID: com.niuyp.BilibiliLive.demo
• installationURL: file:///private/var/containers/Bundle/Application/.../BilibiliLive.app/
```

### 3.4 一键构建并安装脚本

创建一个便捷脚本，将构建和安装合并为一步：

```bash
#!/bin/bash
# 保存为: deploy-to-appletv.sh

# 配置变量
PROJECT_NAME="BilibiliLive"
SCHEME="BilibiliLive"
DEVICE_ID="00008110-00024C9C21DA801E"  # 替换为你的设备 ID

echo "🧹 清理构建缓存..."
rm -rf ~/Library/Developer/Xcode/DerivedData/${PROJECT_NAME}-*

echo "🔨 构建应用..."
xcodebuild -project ${PROJECT_NAME}.xcodeproj \
  -scheme ${SCHEME} \
  -destination "platform=tvOS,id=${DEVICE_ID}" \
  -allowProvisioningUpdates \
  clean build

if [ $? -eq 0 ]; then
  echo "✅ 构建成功！"
  echo "📱 安装到 Apple TV..."

  xcrun devicectl device install app \
    --device ${DEVICE_ID} \
    ~/Library/Developer/Xcode/DerivedData/${PROJECT_NAME}-*/Build/Products/Debug-appletvos/${PROJECT_NAME}.app

  if [ $? -eq 0 ]; then
    echo "🎉 应用已成功安装到 Apple TV！"
    echo "现在可以在 Apple TV 主屏幕找到应用并运行。"
  else
    echo "❌ 安装失败！"
    exit 1
  fi
else
  echo "❌ 构建失败！"
  exit 1
fi
```

使用脚本：
```bash
# 添加执行权限
chmod +x deploy-to-appletv.sh

# 运行脚本
./deploy-to-appletv.sh
```

## 四、在 Apple TV 上运行应用

1. 在 Apple TV 主屏幕找到 **BilibiliLive** 应用图标
2. 点击打开即可使用

## 五、常见问题排查

### 5.1 设备无法发现

**问题：** Xcode 中看不到 Apple TV 设备

**解决方案：**
1. 确认两台设备在同一 Wi-Fi 网络
2. 在 Apple TV 上重新启用"远程App与设备"
3. 尝试重启 Apple TV 和 Mac
4. 手动输入 IP 地址配对

### 5.2 构建失败：database is locked

**问题：** 构建时提示数据库锁定

**解决方案：**
```bash
# 关闭 Xcode
killall Xcode

# 清理构建数据
rm -rf ~/Library/Developer/Xcode/DerivedData/BilibiliLive-*

# 重新构建
```

### 5.3 签名失败

**问题：** 签名时提示证书或配置文件问题

**解决方案：**
1. 在 Xcode 中重新登录 Apple ID
2. 检查 Team 是否正确选择
3. 删除旧的配置文件：
```bash
rm -rf ~/Library/MobileDevice/Provisioning\ Profiles/*
```
4. 重新在 Xcode 中让它自动生成

### 5.4 检查设备连接状态

```bash
# 检查设备是否在线
xcrun devicectl list devices

# 检查设备信息
instruments -s devices 2>&1 | grep -i "jason room"
```

### 5.5 查看详细构建日志

如果需要查看完整的构建过程：

```bash
# 保存完整日志到文件
xcodebuild -project BilibiliLive.xcodeproj \
  -scheme BilibiliLive \
  -destination 'platform=tvOS,id=00008110-00024C9C21DA801E' \
  -allowProvisioningUpdates \
  clean build 2>&1 | tee build.log
```

## 六、重要提示

### 免费 Apple ID 限制

- ⏰ **7天有效期**：使用免费 Apple ID 签名的应用会在 7 天后过期
- 🔄 **需要重新安装**：到期后重复上述构建安装步骤即可
- 📱 **最多 3 台设备**：免费账户最多同时在 3 台设备上安装应用

### 证书过期提醒

应用过期后，Apple TV 会提示"无法验证应用"，此时需要：

```bash
# 重新构建并安装
./deploy-to-appletv.sh
```

### 备份签名配置

建议备份项目配置文件的修改：

```bash
# 创建 git commit 保存更改
git add BilibiliLive.xcodeproj/project.pbxproj
git commit -m "Configure automatic signing for development"
```

## 七、快速参考

### 常用命令速查

```bash
# 查看设备列表
xcrun devicectl list devices

# 查看证书
security find-identity -v -p codesigning

# 测试网络连接
ping -c 3 192.168.1.119

# 构建
xcodebuild -project BilibiliLive.xcodeproj -scheme BilibiliLive \
  -destination 'platform=tvOS,id=YOUR_DEVICE_ID' \
  -allowProvisioningUpdates clean build

# 安装
xcrun devicectl device install app \
  --device YOUR_DEVICE_ID \
  ~/Library/Developer/Xcode/DerivedData/BilibiliLive-*/Build/Products/Debug-appletvos/BilibiliLive.app

# 清理缓存
rm -rf ~/Library/Developer/Xcode/DerivedData/BilibiliLive-*
```

### 设备信息模板

记录你的设备信息：

```
Apple TV 名称：Jason room
Apple TV IP：192.168.1.119
设备 ID：00008110-00024C9C21DA801E
Mac IP：192.168.1.123
```

## 八、自动化脚本（进阶）

### 8.1 检测设备是否在线

```bash
#!/bin/bash
# check-device.sh

DEVICE_ID="00008110-00024C9C21DA801E"

echo "🔍 检查设备连接状态..."
if xcrun devicectl list devices | grep -q "$DEVICE_ID"; then
  echo "✅ 设备已连接"
  exit 0
else
  echo "❌ 设备未连接"
  echo "请检查："
  echo "1. Apple TV 是否开机"
  echo "2. 两台设备是否在同一 Wi-Fi 网络"
  echo "3. Apple TV 的'远程App与设备'是否启用"
  exit 1
fi
```

### 8.2 带进度显示的部署脚本

```bash
#!/bin/bash
# deploy-with-progress.sh

PROJECT_NAME="BilibiliLive"
SCHEME="BilibiliLive"
DEVICE_ID="00008110-00024C9C21DA801E"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}🚀 开始部署流程...${NC}\n"

# 步骤 1: 清理
echo -e "${YELLOW}[1/3] 清理构建缓存...${NC}"
rm -rf ~/Library/Developer/Xcode/DerivedData/${PROJECT_NAME}-*
echo -e "${GREEN}✓ 清理完成${NC}\n"

# 步骤 2: 构建
echo -e "${YELLOW}[2/3] 构建应用...${NC}"
xcodebuild -project ${PROJECT_NAME}.xcodeproj \
  -scheme ${SCHEME} \
  -destination "platform=tvOS,id=${DEVICE_ID}" \
  -allowProvisioningUpdates \
  clean build 2>&1 | grep -E "(BUILD SUCCEEDED|BUILD FAILED|error:)"

if [ ${PIPESTATUS[0]} -eq 0 ]; then
  echo -e "${GREEN}✓ 构建成功${NC}\n"
else
  echo -e "${RED}✗ 构建失败${NC}"
  exit 1
fi

# 步骤 3: 安装
echo -e "${YELLOW}[3/3] 安装到 Apple TV...${NC}"
xcrun devicectl device install app \
  --device ${DEVICE_ID} \
  ~/Library/Developer/Xcode/DerivedData/${PROJECT_NAME}-*/Build/Products/Debug-appletvos/${PROJECT_NAME}.app

if [ $? -eq 0 ]; then
  echo -e "\n${GREEN}🎉 部署成功！应用已安装到 Apple TV${NC}"
  echo -e "${YELLOW}⏰ 提醒：应用将在 7 天后过期，需要重新安装${NC}"
else
  echo -e "${RED}✗ 安装失败${NC}"
  exit 1
fi
```

## 总结

通过以上步骤，你可以使用免费 Apple ID 将应用部署到 Apple TV 4K 进行测试。虽然有 7 天的限制，但对于开发和测试来说已经足够。如果需要长期使用，建议购买 Apple Developer Program（99美元/年）。

---

**文档创建时间**：2025-10-01
**适用版本**：Xcode 17+, tvOS 16.0+
**作者**：Claude Code Assistant
