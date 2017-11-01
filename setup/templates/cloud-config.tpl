#cloud-config
# Order of cloud-init execution - https://stackoverflow.com/a/37190866/138469
hostname: ${user}
repo_update: true
repo_upgrade: all
packages:
  - tree
  - zip
  - jq
  - graphviz # allow ppl to run dot
  # docker requirements
  - apt-transport-https
  - ca-certificates
  - software-properties-common

# one time setup
runcmd:
  - /usr/local/sbin/install_terraform.sh
  - /usr/local/sbin/install_kubectl.sh
  - /usr/local/sbin/install_helm.sh
  - /usr/local/sbin/install_docker.sh
  - /usr/local/sbin/install_consul.sh
  - /usr/local/sbin/install_sigil.sh
  - /usr/local/sbin/install_usql.sh
  - /usr/local/sbin/setup_ws.sh
  - sed -ie "s/^PasswordAuthentication no/PasswordAuthentication yes/g" /etc/ssh/sshd_config
  - service ssh restart

output:
  all: '| tee -a /var/log/cloud-init-output.log'

groups:
  - training
# see http://cloudinit.readthedocs.io/en/latest/topics/modules.html#users-and-groups
users:
  - default
  - name: training
    primary-group: training
    groups: sudo
    shell: /bin/bash
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    lock_passwd: false
    passwd: "$6$YgikR5Kw$jM0fdsIsxqbR0FA.esbX7mQyzRhn25ovC4lJkmTNBh/KgUI3lBOmo0hCPLrgkiyMRDI/XHl7WtzbMxrxm2eKD0" #${training_password_hash}

write_files:
  - path: /usr/local/sbin/install_terraform.sh
    permissions: '0755'
    content: |
        #!/bin/bash
        VERSION=${tf_version}
        curl -Lo ~/terraform.zip https://releases.hashicorp.com/terraform/$${VERSION}/terraform_$${VERSION}_linux_386.zip
        cd ~
        unzip terraform.zip && rm terraform.zip
        mv terraform /usr/bin/
  - path: /usr/local/sbin/install_sigil.sh    
    permissions: '0755'
    content: |
        #!/bin/bash
        VERSION=${sigil_version}
        ARCH=$(uname -sm|tr \  _)
        curl -L https://github.com/gliderlabs/sigil/releases/download/v$${VERSION}/sigil_$${VERSION}_$${ARCH}.tgz | tar -zxC /usr/local/bin
  - path: /usr/local/sbin/setup_ws.sh    
    permissions: '0755'
    content: |
        #!/bin/bash
        cd ~training
        git clone https://github.com/honestbee/flask_app_k8s.git
        git clone ${git_repo} ${ws_dir}
        cd ${ws_dir}
        sigil -p -f main.tf.tpl aws_key=${aws_key} aws_secret=${aws_secret} aws_region=${aws_region} > main.tf
        sigil -p -f terraform.tfvars.tpl aws_key=${aws_key} aws_secret=${aws_secret} > terraform.tfvars
        sigil -p -f rds/terraform.tfvars.tpl aws_key=${aws_key} aws_secret=${aws_secret} > rds/terraform.tfvars
        rm *.tpl
        # remove workshop setup sub-folder
        rm -rf setup/
        cd ..
        chown -R training:training ${ws_dir}/
        chown -R training:training flask_app_k8s/
  - path: /usr/local/sbin/install_kubectl.sh
    permissions: '0755'
    content: |
        #!/bin/bash
        VERSION=${kubectl_version}
        curl -Lo /usr/bin/kubectl https://storage.googleapis.com/kubernetes-release/release/$${VERSION}/bin/linux/amd64/kubectl
        chmod +x /usr/bin/kubectl
  - path: /usr/local/sbin/install_helm.sh
    permissions: '0755'
    content: |
        #!/bin/bash
        VERSION=${helm_version}
        curl -Lo ~/helm.tar.gz https://storage.googleapis.com/kubernetes-helm/helm-$${VERSION}-linux-amd64.tar.gz
        cd ~
        tar -xzf helm.tar.gz && rm helm.tar.gz
        mv linux-amd64/helm /usr/bin/ && rm -rf linux-amd64
  - path: /usr/local/sbin/install_usql.sh
    permissions: '0755'
    content: |
        #!/bin/bash
        VERSION=${usql_version}
        curl -Lo ~/usql.tar.bz2 https://github.com/xo/usql/releases/download/v$${VERSION}/usql-$${VERSION}-linux-amd64.tar.bz2
        cd ~
        tar -xjf usql.tar.bz2 && rm usql.tar.bz2
        mv usql /usr/bin/
  - path: /usr/local/sbin/install_consul.sh
    permissions: '0755'
    content: |
        #!/bin/bash
        VERSION=${consul_version}
        curl -Lo ~/consul.zip https://releases.hashicorp.com/consul/$${VERSION}/consul_$${VERSION}_linux_amd64.zip
        cd ~
        unzip consul.zip && rm consul.zip
        mv consul /usr/bin/
  - path: /usr/local/sbin/install_docker.sh
    permissions: '0755'
    content: |
        #!/bin/bash
        VERSION=${docker_version}
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
        sudo add-apt-repository \
          "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
          $(lsb_release -cs) \
          stable"
        sudo apt-get update
        sudo apt-get install docker-ce=$${VERSION} -y
        sudo usermod -aG docker training
