# 本地编译指南 (Cudy TR3000 128M U-Bootmod)

本指南面向 **Windows 用户**，教你在本地搭建 Ubuntu 环境编译 ImmortalWrt 固件。

---

## 一、搭建 Ubuntu 环境 (WSL2)

### 1. 启用 WSL2

以 **管理员身份** 打开 PowerShell，执行：

```powershell
wsl --install -d Ubuntu-24.04
```

安装完成后按提示设置用户名和密码，重启电脑。

### 2. 进入 Ubuntu

打开开始菜单搜索 **Ubuntu** 或在 PowerShell 中输入：

```powershell
wsl
```

### 3. 确保磁盘空间充足

编译至少需要 **30GB** 可用空间。WSL 默认安装在 C 盘，如果空间不足可以迁移：

```powershell
# 在 PowerShell (管理员) 中执行
wsl --shutdown
wsl --export Ubuntu-24.04 D:\wsl-backup.tar
wsl --unregister Ubuntu-24.04
wsl --import Ubuntu-24.04 D:\WSL\Ubuntu-24.04 D:\wsl-backup.tar
```

---

## 二、获取编译脚本

在 Ubuntu 终端中执行：

```bash
# 安装 git
sudo apt update && sudo apt install -y git

# 克隆仓库
git clone git@github.com:taurusxin/immortalwrt-cudy-tr3000.git
cd immortalwrt-cudy-tr3000
```

---

## 三、开始编译

```bash
# 赋予脚本执行权限
chmod +x build.sh

# 开始编译 (首次约 2-4 小时，取决于机器性能)
./build.sh
```

编译完成后固件输出在 `firmware/` 目录下。

### 可选参数

| 参数 | 说明 |
|------|------|
| `--menuconfig` | 编译前打开配置菜单，自定义软件包 |
| `--clean` | 清除源码和缓存，重新编译 |
| `--no-ccache` | 不使用编译缓存 |
| `--jobs N` | 指定并行编译线程数 (默认自动检测) |
| `--commit HASH` | 指定上游源码的 commit |

示例：

```bash
# 自定义配置后编译
./build.sh --menuconfig

# 清除缓存重新编译
./build.sh --clean

# 指定 4 线程编译
./build.sh --jobs 4
```

---

## 四、获取固件

编译产物位于项目目录下的 `firmware/` 文件夹：

```
firmware/
  immortalwrt-mediatek-filogic-cudy_tr3000-v1-ubootmod-squashfs-sysupgrade.bin
```

### 在 Windows 中访问 WSL 文件

打开文件资源管理器，地址栏输入：

```
\\wsl$\Ubuntu-24.04\home\你的用户名\immortalwrt-cudy-tr3000\firmware
```

或者在 Ubuntu 终端中直接复制到 Windows 桌面：

```bash
cp firmware/*.bin /mnt/c/Users/你的Windows用户名/Desktop/
```

---

## 五、刷入固件

本固件适用于已刷入 DHCP U-Boot 的 Cudy TR3000 (128M 闪存版本)。

1. 电脑连接路由器 LAN 口
2. 设置电脑 IP 为 `192.168.1.2`，子网掩码 `255.255.255.0`
3. 浏览器打开 `http://192.168.1.1` 进入 U-Boot 恢复页面
4. 上传 `sysupgrade.bin` 固件
5. 等待刷写完成，路由器自动重启

刷入完成后，路由器管理地址为 `10.10.0.1`。

---

## 常见问题

### Q: 编译中途报错怎么办？

```bash
# 查看详细错误日志
./build.sh --no-ccache --jobs 1
```

### Q: 如何更新上游源码后重新编译？

```bash
cd openwrt
git pull
cd ..
./build.sh
```

### Q: ccache 占用太大怎么办？

```bash
# 清除 ccache 缓存
ccache -C
```

### Q: WSL 内存不够用？

在 Windows 用户目录创建 `.wslconfig` 文件 (`C:\Users\你的用户名\.wslconfig`)：

```ini
[wsl2]
memory=8GB
swap=4GB
```

保存后在 PowerShell 中执行 `wsl --shutdown` 重启 WSL。
