## Lanza az-login
echo "**************************************************"
echo "***           Logging Azure CLI                ***"
echo "**************************************************"
echo ""

az login

## Cambia al directorio de Terraform y ejecuta Terraform Init
echo ""
echo "**************************************************"
echo "***          Executing Terraform               ***"
echo "**************************************************"
echo ""
cd ./terraform && terraform init

## Ejecuta Terraform apply y terraform plan si el apply funciona (Si no se modifica el código de Terraform, debe funcionar)
## Esto promptea 2 veces para rellenar las vars que no son default (tanto para el plan como el apply)
terraform apply --auto-approve

## Configurar el sistema host con las configuraciones propuestas de Azure
echo ""
echo "**************************************************"
echo "***          Exporting TF Outputs              ***"
echo "**************************************************"
echo ""

terraform output -raw kube_config > ~/.kube/aksconfig
terraform output -raw ssh_private_key_file > ../cp2key.pem
export ssh_private_key_file=$(echo "../cp2key.pem")
chmod 600 ../cp2key.pem

## Rellena los ficheros "ansible.cfg" y "secrets.yml" con los datos extraídos de Azure
export acr_login_url=$(terraform output -raw acr_login_url)
export acr_password=$(terraform output -raw acr_password)
export acr_username=$(terraform output -raw acr_username)
export vm_admin_username=$(terraform output -raw vm_admin_username)
export vm_public_ip=$(terraform output -raw vm_public_ip)

echo ""
echo "**************************************************"
echo "***          Seeding Ansible files             ***"
echo "**************************************************"
echo ""

cat <<EOF >> ../ansible/secrets.yml 
acr_login_url: ${acr_login_url}
acr_password: ${acr_password} 
acr_username: ${acr_username} 
vm_admin_username: ${vm_admin_username}
nginx_user: user
nginx_password: 1234
EOF

cat <<EOF >> ../ansible/ansible.cfg 
[defaults]
remote_user = ${vm_admin_username}
private_key_file = ${ssh_private_key_file}
vm_public_ip = ${vm_public_ip}
inventory = ./azure_rm.yaml
host_key_checking = False

[inventory]
enable_plugins = azure.azcollection.azure_rm
EOF

##  Cambia de directorio a Ansible para securizar los secrets y lanzar los playbooks
cd ../ansible

echo ""
echo "**************************************************"
echo "***       Encrypting Ansible secrets           ***"
echo "**************************************************"
echo ""

ansible-vault encrypt secrets.yml

echo ""
echo "**************************************************"
echo "***           Executing Ansible                ***"
echo "**************************************************"
echo ""

ansible-playbook -i hosts.ini -i azure_rm.yaml playbook.yml --ask-vault-pass
