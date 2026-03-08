#!/bin/bash

echo "🚀 Iniciando a configuração do ambiente..."

# 1. Atualizar o sistema e instalar dependências do repositório
echo "📦 Instalando pacotes básicos (curl, git, vim, pipx, exa)..."
sudo apt update
sudo apt install -y curl wget git vim pipx unzip exa

# 2. Instalar o Ansible
echo "⚙️ Instalando o Ansible via pipx..."
pipx install ansible
pipx ensurepath

# 3. Instalar o Starship
echo "⭐ Instalando o Starship..."
curl -sS https://starship.rs/install.sh | sh -s -- -y

# 4. Instalar ferramentas do Kubernetes (kubectl e kubecolor)
echo "☸️ Instalando o kubectl e kubecolor..."
if ! command -v kubectl &> /dev/null; then
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl
fi

if ! command -v kubecolor &> /dev/null; then
    KUBECOLOR_VERSION=$(curl -s https://api.github.com/repos/kubecolor/kubecolor/releases/latest | grep tag_name | cut -d '"' -f 4)
    curl -LO "https://github.com/kubecolor/kubecolor/releases/download/${KUBECOLOR_VERSION}/kubecolor_${KUBECOLOR_VERSION#v}_linux_amd64.tar.gz"
    tar -xzf "kubecolor_${KUBECOLOR_VERSION#v}_linux_amd64.tar.gz" kubecolor
    sudo mv kubecolor /usr/local/bin/
    rm "kubecolor_${KUBECOLOR_VERSION#v}_linux_amd64.tar.gz"
fi

# 5. Instalar o NVM
echo "🟢 Instalando o NVM..."
if [ ! -d "$HOME/.nvm" ]; then
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
fi

# 6. Preparar diretórios essenciais
echo "📁 Criando pastas do SSH e do Kubernetes..."
mkdir -p ~/.ssh ~/.kube/configs
chmod 700 ~/.ssh ~/.kube

# 7. Injetar as configurações customizadas no Bash
echo "📝 Configurando seus aliases e funções personalizadas..."

cat << 'EOF' > ~/.bash_custom

# Inicialização do Starship
eval "$(starship init bash)"

# Aliases seguros condicionados à instalação
if command -v kubectl >/dev/null; then
    if command -v kubecolor >/dev/null; then
        alias kubectl="kubecolor"
    fi
fi

alias k="kubectl"
alias kc="kubectl config use-context"
alias k-get-all="kubectl api-resources --verbs=list --namespaced -o name | xargs -n 1 kubectl get --show-kind --ignore-not-found"

if command -v exa >/dev/null; then
    alias ls="exa"
fi

alias apply="exec $SHELL"
alias ".."="cd .."
alias "bashrc"="vim ~/.bashrc"

# Aliases do WSL (Apenas ativados se o Ubuntu estiver rodando dentro do Windows)
if grep -qEi "(Microsoft|WSL)" /proc/version &> /dev/null; then
    alias idea='"/mnt/c/Program Files/JetBrains/IntelliJ IDEA 2024.3.1.1/bin/idea64.exe"'
    alias explorer="explorer.exe"
fi

# Funções do K3s
copyk3s () {
    host=$1; password=$2; file_to_append_to=$3; cluster_name=$4
    ssh $host "echo '$password' | sudo -S cat /etc/rancher/k3s/k3s.yaml" | tee $file_to_append_to
    sed -i "s|default|$cluster_name|g" $file_to_append_to
    node_ip=$(echo -n $host | grep -oP "(?<=@).*")
    sed -i "s|127.0.0.1|$node_ip|g" $file_to_append_to
}

copyk3s-nopass () {
    host=$1; file_to_append_to=$2; cluster_name=$3
    ssh $host "sudo cat /etc/rancher/k3s/k3s.yaml" | tee $file_to_append_to
    sed -i "s|default|$cluster_name|g" $file_to_append_to
    node_ip=$(echo -n $host | grep -oP "(?<=@).*")
    sed -i "s|127.0.0.1|$node_ip|g" $file_to_append_to
}

# Configuração dinâmica do KUBECONFIG
if [[ -f ~/.kube/config ]]; then
    export KUBECONFIG="${HOME}/.kube/config"
fi
if [[ -d ~/.kube/configs ]]; then
    for config in ~/.kube/configs/*; do
        export KUBECONFIG="$KUBECONFIG:$config"
    done
fi
EOF

# Adiciona a chamada para o seu arquivo customizado no .bashrc padrão do Ubuntu
if ! grep -q ".bash_custom" ~/.bashrc; then
    echo "" >> ~/.bashrc
    echo "# Carrega configurações e aliases personalizados" >> ~/.bashrc
    echo "if [ -f ~/.bash_custom ]; then . ~/.bash_custom; fi" >> ~/.bashrc
fi

echo "✅ Configuração concluída com sucesso!"
echo "➡️  Próximos passos:"
echo "1. Coloque sua chave SSH na pasta ~/.ssh/ e rode: chmod 600 ~/.ssh/sua_chave"
echo "2. Copie seus arquivos do Kubernetes para a pasta ~/.kube/configs/"
echo "3. Reinicie o terminal ou rode: source ~/.bashrc"
