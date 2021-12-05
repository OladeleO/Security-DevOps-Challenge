#! /bin/bash
sudo apt update
sudo apt -y install apache2
sudo service apache2 start
sudo echo "<html><body><p>Hi this is my wonderful Hello World page !</p></body></html>" > /var/www/html/index.html
