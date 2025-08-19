# 灵感相机 (Inspire Camera)

**灵感相机 (Inspire Camera)** 是一款智能相机应用，它不仅仅是捕捉画面，更是激发你的创造力。借助先进的 AI 技术，它能实时分析你镜头中的世界，并从多个维度（如光影诗人、文字诗人、博物学者等）为你提供独特的解读和灵感。

![应用图标](AICamera/Assets.xcassets/AppIcon.appiconset/1024.png)

## ✨ 功能特性

* **实时灵感分析**: 将镜头对准任何场景，AI 会即时为你提供富有创意的解读和描述。
* **多重灵感角色**: 你可以切换不同的 AI 角色（如“光影诗人”、“生活禅师”），从不同视角获取独特的创意启发。
* **AI 图像/视频生成**:
    * **唤醒画中梦**: 将你的照片一键转化为动漫风格的艺术画作。
    * **重塑时光影**: AI 会根据照片内容自动生成短视频脚本，并为你创作一段独一无二的动态影像。
* **记忆回廊**: 所有拍摄的照片、生成的作品以及 AI 的灵感解读都会被珍藏在应用的“记忆回廊”中，方便你随时回顾和二次创作。
* **高光卷轴**: AI 可以自动将你的多张照片编织成一个有故事性的高光时刻，并生成适合在社交媒体分享的标题、文案和标签。
* **高度可定制**:
    * **双 AI 服务商支持**: 你可以根据自己的需求，在豆包大模型和 OpenAI 之间自由切换。
    * **自定义 Prompts**: 所有的 AI 功能（包括各个灵感角色、图像/视频创作等）的背后指令（Prompts）都可以在设置中自由修改，让 AI 更懂你。

## 🛠️ 技术栈

* **UI**: SwiftUI
* **数据持久化**: SwiftData
* **相机**: AVFoundation
* **AI 服务**:
    * 豆包大模型 (Doubao)
    * OpenAI

## 🚀 如何开始

### 环境要求

* iOS 17.0+
* Xcode 15.0+
* Swift 5.9+

### 安装步骤

1.  **克隆代码库**
    ```bash
    git clone [https://github.com/your-username/InspireCamera.git](https://github.com/your-username/InspireCamera.git)
    ```
2.  **打开项目**
    使用 Xcode 打开 `AICamera.xcodeproj`。
3.  **配置 API 密钥**
    * 在 `AICamera/ViewModels/AppSettings.swift` 文件中，你可以找到默认的 API Key 配置。
    * **强烈建议**: 启动应用后，在设置页面中换上你自己的豆包或 OpenAI API 密钥，以确保应用的稳定运行。
4.  **编译并运行**
    选择你的目标设备（真机或模拟器），然后点击 "Run" 按钮。

## 🤝 如何贡献

我们非常欢迎社区的贡献！如果你有任何建议、想要修复 Bug 或添加新功能，请遵循以下步骤：

1.  **Fork** 本项目
2.  创建一个新的分支 (`git checkout -b feature/YourAmazingFeature`)
3.  提交你的修改 (`git commit -m 'Add some AmazingFeature'`)
4.  将你的分支推送到远程仓库 (`git push origin feature/YourAmazingFeature`)
5.  创建一个 **Pull Request**

我们期待你的加入，一起让“灵感相机”变得更出色！

## 📄 开源许可证

本项目基于 [MIT License](LICENSE) 开源。
