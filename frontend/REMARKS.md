### TODO



### done 
 - 首页改成match 列表
 - 更换logo
 - 语音语页：放大录单按钮，默认是语言输入，有按钮可切换到文字输入
 - 将web版直接发布到docs/app目录下
 - 整理目录与README

### 后端信息

后端入口：
https://whisper-coach.dacheng.dev
后端API文档
https://whisper-coach.dacheng.dev/docs

### cmd
flutter clean
flutter pub get
flutter run
flutter run -d chrome --web-port 3000

#### build web版

flutter build web
``` 构建并发布到pages
 sh scripts/build-web-git-docs.sh
```
- base-href: `/whisper_coach/app/`