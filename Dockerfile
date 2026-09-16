# sanSENJIAN/qq-music-api 修正版 Dockerfile
# 变更点（相对上游 main 分支版本）：
# 1. node:22.22.1-alpine -> node:24-alpine
#    仓库 CI（ci.yml/test.yml/package.yml）全部用 Node 24 + 精确锁定的 npm 11.14.1；
#    node:22 镜像内置 npm 10.x，与仓库锁定的 npm 11 行为有差异，且 engines 声明要求 npm ^11。
# 2. 增加 COPY package-lock.json
#    .npmrc 已声明 package-lock=true，CI 全靠锁文件保证依赖一致；原 Dockerfile 不拷锁文件，
#    每次构建都重新解析依赖版本（上游发了不兼容的新版本就会把你的构建搞挂，本次失败即此类）。
# 3. npm install -> npm ci
#    严格按锁文件安装、不重新解析版本，与 CI 的依赖组合完全一致；npm >= 8.1 默认会把
#    锁文件里的 registry.npmjs.org 地址替换成 --registry 指定的镜像源，npmmirror 依然生效。
# 4. 保留 packages/mcp/package.json 的 COPY（root workspaces 声明了该子包，缺它 npm 会报错）。
FROM node:24-alpine

LABEL maintainer="your-dockerhub-username"

WORKDIR /app

# 先只拷贝依赖清单，利用 Docker 层缓存：代码变更不触发重新安装依赖
COPY package.json package-lock.json ./
COPY packages/mcp/package.json ./packages/mcp/

RUN npm ci --registry=https://registry.npmmirror.com

COPY . .

RUN npm run build

EXPOSE 3200

ENTRYPOINT ["npm", "run"]
CMD ["start"]

# ---- 备注 ----
# 1. 若 npm ci 报 "lock file out of sync"（比如你 fork 上的 version.yml 改了版本号但没重新生成锁文件），
#    临时回退方案：把 npm ci 那行换成
#      RUN npm install -g npm@11.14.1 && npm install --registry=https://registry.npmmirror.com
# 2. GitHub Actions 内构建时网络走国际线路，可删掉 --registry 参数直连 npmjs，速度更快。
# 3. 服务器是 ARM 架构（如 Oracle/AWS Graviton）时，docker.yml 加 platform: linux/arm64，
#    此镜像无原生模块，QEMU 交叉构建可接受。
