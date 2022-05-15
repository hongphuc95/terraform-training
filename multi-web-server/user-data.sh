#!/bin/bash

apt-get update
apt install -y apache2
systemctl start apache2
systemctl enable apache2
EC2_AVAIL_ZONE=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
echo "<h1> Hello from $(hostname -f) in AZ $EC2_AVAIL_ZONE </h1>" > /var/www/html/index.html