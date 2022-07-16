# All in Kubernetes

> All-In-One（~~all in boom~~）。

此项目致力于简化部署 Kubernetes 流程 ，整合零散设备，提高设备利用率。

## 特性

- 统一化应用管理，降低传统的硬件虚拟化带来的应用碎片化问题
- 整合账户系统，使用 *LDAP* 来管理用户
- 完全使用 `yaml` 配置来管理和部署集群

## 入门

项目发布于 [document/all-in-kubernetes](https://gitlab.open-edgn.cn/document/all-in-kubernetes)
，且实时同步到 [d7z-project/all-in-kubernetes](https://github.com/d7z-project/all-in-kubernetes)。
如有问题可在 [Github](https://github.com/d7z-project/all-in-kubernetes/issues) 提问或发送邮件给我。如果你有新的想法可提 **Pull request**
，如需在线阅读请访问 [d7z-project.github.io/all-in-kubernetes](https://d7z-project.github.io/all-in-kubernetes/)
或者是 [all-in-kubernetes.docs.d7z.net](https://all-in-kubernetes.docs.d7z.net)。

**注意：** 此项目需要你有 Kubernetes 的基础知识，可前往 [Kubernetes 文档](https://kubernetes.io/zh-cn/docs/home/) 在线学习。

## 导出文档

执行以下命令：

```bash
# 安装工具链
sudo ./.doc/doc.sh toolchain
# 导出文档
./.doc/doc.sh build `pwd`
```

如无意外，将导出在 `/build` 目录

## 注意事项

如果你因为此项目导致 **数据丢失** 、**机器损坏** 等不可挽回的问题，此项目的贡献者均 **不会承担任何责任** ，你可提交你的部署流程帮助我们分析并解决问题 。**数据无价，请一定做好数据备份** ！

## License

此文档/工程/仓库使用 [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)，具体细节请查看 [LICENSE](./LICENSE) 文件。
