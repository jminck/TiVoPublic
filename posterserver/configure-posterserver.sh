DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd $DIR
pwd

#install ansible and playbooks
sudo yum install epel-release -y
sudo yum install facter -y
sudo yum install ansible -y
sudo yum install wget -y
sudo ansible-galaxy install geerlingguy.nfs
sudo ansible-galaxy install geerlingguy.apache

#add to bottom of /etc/ansible/hosts
sudo bash -c "cat >> /etc/ansible/hosts" << EOL
[local]
localhost ansible_connection=local
EOL

sudo bash -c "cat >> /etc/ansible/ansible.cfg" << EOL
[defaults]
log_path=/var/log/ansible.log
EOL

#run the playbook
sudo ansible-playbook ./playbook.yml --connection=local -vvvv
#run it again because creating config files from templates fails the first time :\
sudo ansible-playbook ./playbook.yml --connection=local -vvvv


