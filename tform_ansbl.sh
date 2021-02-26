#!/bin/bash
terraform apply -auto-approve &&\
echo "terraform already done, now you need wait 20sec"
for i in {0..20}
do
   echo "$i sec"
   sleep 1
done
echo "now ansible will works"
ansible-playbook playbook.yml
