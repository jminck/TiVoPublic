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

#run the playbook
sudo ansible-playbook ./playbook.yml --connection=local

