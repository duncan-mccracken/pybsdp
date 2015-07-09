RHEL Setup
==========
useradd -m shelluser
echo shelluser:shelluser | chpasswd
usermod -a -G adm shelluser
curl -O http://172.16.207.1/~dcmccracken/pybsdp.tgz
mkdir -p /tmp/pybsdp
tar -xzvf pybsdp.tgz -C /tmp/pybsdp/
chown -R root:root /tmp/pybsdp/
/tmp/pybsdp/install.sh 
rm -f pybsdp.tgz


Ubuntu Setup
============
sudo -s
wget http://172.16.207.1/~dcmccracken/pybsdp.tgz
mkdir -p /tmp/pybsdp
tar -xzvf pybsdp.tgz -C /tmp/pybsdp/
chown -R root:root /tmp/pybsdp/
/tmp/pybsdp/install.sh 
rm -f pybsdp.tgz
