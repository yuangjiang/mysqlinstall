#!/bin/bash
echo "***********************************************"
echo "*           欢迎使用  MySQL  安装脚本         *"
echo "***********************************************"
#MySQL数据目录
mdatadir=/mnt/mysql/data
#MySQL初始化密码
setpwd=123456
#安装文件
tarFile=/root/mysql-5.7.26-1.el7.x86_64.rpm-bundle.tar
#解压目录
tarDir=/usr/local/src/mysql-5.7.26
#ISO光盘挂载位置
isoFile=/media/iso
mkdir -p $mdatadir
if [[ `awk -F: '{ print $1 }' /etc/passwd | grep mysql` != mysql ]];then
  echo "正在创建用户..."
  groupadd mysql
  useradd -g mysql mysql
  chown -R mysql:mysql $mdatadir
  ln -s $mdatadir /var/lib/mysql
  chown mysql:mysql /var/lib/mysql
else
 echo "用户已存在..."
fi
echo "正在检测是否安装wget..."
if [[ `yum list installed | grep wget |wc -l` -ne 0 && `yum list installed | grep createrepo |wc -l` -ne 0 ]];then
echo "createrepo,wget已安装"
else
yum -y install wget createrepo
fi
if [[ -f "$tarFile" ]];then
   echo "开始安装MySQL..."
else
   echo "安装文件不存在...退出安装!!!"
   exit
fi
if [ -d "$tarDir" ];then
echo "$tarDir 文件夹已存在"
rm -rf $tarDir
echo "文件解压中..."
else
echo "文件解压中..."
fi
mkdir $tarDir
cd $tarDir
tar xvf $tarFile -C $tarDir
cd $tarDir
echo "开始创建本地MySQL安装源..."
createrepo .
echo "正在检测是否安装libnuma.so.1..."
if [ `yum list installed | grep libnuma.so.1 |wc -l` -ne 0 ];then
echo "正在卸载libnuma.so.1"
yum remove libnuma.so.1
else
echo "未安装libnuma.so.1"
fi
echo "正在检测是否安装numactl.x86_64..."
if [ `yum list installed | grep numactl.x86_64 |wc -l` -ne 0 ];then
echo "numactl.x86_64已安装"
else
yum -y install numactl.x86_64
fi
echo "正在检测是否安装libaio-devel..."
if [ `yum list installed | grep libaio-devel |wc -l` -ne 0 ];then
echo "libaio-devel已安装"
else
yum -y install libaio-devel
fi
echo "正在创建MySQL本地安装源..."
if [[ -f /dev/sr0 ]];then
mkdir $isoFile
mount -t iso9660 -o loop /dev/sr0 $isoFile
if [[ -f "/etc/yum.repos.d/cdrom.repo" ]];then
   echo "操作系统本地源已存在"
else
   echo -e "[CDROM]\nname=isofile\nbaseurl=file:///media/iso\nenabled=1\ngpgcheck=0\ngpgkey=file:///media/iso/RPM-GPG-KEY-redhat-release" >> /etc/yum.repos.d/cdrom.repo
 fi
fi
if [[ -f "/etc/yum.repos.d/mysql.repo" ]];then
  echo "MySQL 安装源已创建开始尝试安装....."
else
  echo -e "[MySQL-5.7.25]\nname=isofile\nbaseurl=file:///usr/local/src/mysql-5.7.26\nenabled=1\ngpgcheck=0" >> /etc/yum.repos.d/mysql.repo
fi
echo "开始配置基础环境....."
setenforce 0
sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
systemctl stop firewalld.service
systemctl disable firewalld.service
echo "正在安装MySQL..."
yum install -y mysql-server
if [[ $? -ne 0 ]];then
 yum install -y mysql-community-server
fi
echo "正在检测是否安装net-tools..."
if [ `yum list installed | grep net-tools |wc -l` -ne 0 ];then
echo "net-tools已安装"
else
yum -y install net-tools
fi
if netstat -an | grep ':3306';then
echo "3306端口已被占用"
echo "端口被占用，即将退出脚本，请检查端口号"
exit
else
echo "3306端口未被占用"
fi
echo "正在启动MySQL..."
systemctl start mysqld
systemctl status mysqld
systemctl enable mysqld
tpwd=`grep "A temporary password" /var/log/mysqld.log| awk '{ print $NF}'`
echo "默认密码是$tpwd"
echo "正在修改初始密码..."
mysql -uroot -p$tpwd --connect-expired-password -e "set global validate_password_policy=0;set global validate_password_length=0;SET PASSWORD = PASSWORD('$setpwd');"
echo -e "MySQL安装完成, 默认账号为:\033[31m root \033[0m, 密码为:\033[31m $setpwd \033[0m, 开始验证安装......"
mysql -uroot -p$setpwd -e "set global validate_password_policy=0;set global validate_password_length=0;show databases;SHOW VARIABLES LIKE 'validate_password%';grant all privileges on *.* to 'root'@'%' identified by '$setpwd' with grant option;flush privileges;"
echo "设置MySQL字符集编码为utf8...."
sed -i '2a \[client]\ndefault-character-set=utf8\n' /etc/my.cnf
sed -i '$a #\ndefault-storage-engine=INNODB\ncharacter-set-server=utf8\ncollation-server=utf8_general_ci' /etc/my.cnf
systemctl restart mysqld
echo "执行清理...."
rm -rf $tarFile
netName=`ifconfig | awk -F'[ :]+' '!NF{if(eth!=""&&ip=="")print eth;eth=ip4=""}/^[^ ]/{eth=$1}/inet addr:/{ip=$4}' | grep e`
ipName=`ifconfig ens33 | grep "inet " | awk '{ print $2 }' |awk -F '\\\\.' '{print $ipName}'`
echo "主机名:`hostname`  绑定网卡名称:$netName  绑定网卡IP:$ipName"
