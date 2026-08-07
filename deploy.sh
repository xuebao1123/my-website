cd haige
npm install

cd .. # 回到项目根目录
chmod +x update-index.sh
bash update-index.sh             # 执行更新脚本
cd haige                     # 返回 haige 目录

npm run build
cd ..
cp -r haige/build/* ./
