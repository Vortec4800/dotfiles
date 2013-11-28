git pull
read -p "This may overwrite existing files in your home directory. Are you sure? (y/n) " -n 1
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  rsync --exclude ".git/" --exclude ".DS_Store" --exclude "bootstrap.sh" --exclude "README.md" -av . ~
fi

echo ""
echo "Please enter your First and Last name: "
read name
git config --global user.name "$name"

echo "Please enter your work email: "
read email
git config --global user.email "$email"

./.osx
