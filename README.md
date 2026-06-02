# Guia de Instalação e Execução do Lua no Windows

## 📋 Índice

1. [Instalação do Lua](#instalação-do-lua)
2. [Configuração do VS Code](#configuração-do-vs-code)
3. [Executando Arquivos Lua](#executando-arquivos-lua)
4. [Solução de Problemas](#solução-de-problemas)

---

## 🛠️ Instalação do Lua

### Opção 1: Usando o Instalador (Recomendado)

1. **Baixar o Lua**
   - Acesse: [lua.org/download](https://www.lua.org/download.html)
   - Procure pela versão mais recente do Lua para Windows
   - Baixe o arquivo `.exe` (por exemplo: `lua-5.4.6_Win64_bin.zip`)

2. **Extrair o Arquivo**
   - Descompacte o arquivo baixado em uma pasta, por exemplo: `C:\Lua`

3. **Adicionar Lua ao PATH do Windows**
   - Abra o **Menu Iniciar** e pesquise por "Variáveis de Ambiente"
   - Clique em "Editar as variáveis de ambiente do sistema"
   - Na janela que abrir, clique em "Variáveis de Ambiente..."
   - Em "Variáveis de usuário" ou "Variáveis do sistema", clique em "Novo"
   - Nome da variável: `PATH`
   - Valor: `C:\Lua` (ou o caminho onde você extraiu o Lua)
   - Clique em "OK"

4. **Verificar a Instalação**
   - Abra o **Prompt de Comando** (cmd) ou **PowerShell**
   - Digite: `lua -v`
   - Você deve ver a versão do Lua instalada

### Opção 2: Usando Chocolatey (se já tem instalado)

```bash
choco install lua
```

### Opção 3: Usando Git Bash ou WSL

Se você tiver Git Bash instalado:

```bash
# No Git Bash
pacman -S lua
```

---

## 🎨 Configuração do VS Code

### 1. Instalar Extensões Necessárias

1. Abra o VS Code
2. Vá para a seção de **Extensões** (Ctrl + Shift + X)
3. Procure e instale as seguintes extensões:
   - **Lua** (por `sumneko`) - Linguagem Lua com IntelliSense
   - **Code Runner** (por `formulahendry`) - Para executar código rapidamente
   - **Lua Debug** (opcional) - Para debugar código Lua

### 2. Configurar Code Runner (Recomendado)

1. Abra o **settings.json** do VS Code:
   - Pressione `Ctrl + Shift + P`
   - Digite "Preferences: Open Settings (JSON)"
   - Pressione Enter

2. Adicione as seguintes configurações:

```json
{
  "code-runner.executorMap": {
    "lua": "lua"
  },
  "code-runner.runInTerminal": true
}
```

### 3. Configurar Lua Language Server (Opcional, para melhor IntelliSense)

1. Nas **Settings** do VS Code (Ctrl + ,)
2. Procure por "Lua" e configure conforme necessário
3. Recomendações padrão funcionam bem para a maioria dos casos

---

## ▶️ Executando Arquivos Lua

### Opção 1: Usando Code Runner (Mais Fácil)

1. Abra um arquivo `.lua` no VS Code
2. Clique com o botão direito no editor
3. Selecione **"Run Code"** ou use o atalho: **Ctrl + Alt + N**

Você verá a saída no terminal integrado do VS Code.

### Opção 2: Executar via Terminal Integrado

1. Abra o arquivo `.lua` no VS Code
2. Abra o terminal integrado: **Ctrl + `**
3. Digite o comando:

```bash
lua seu_arquivo.lua
```

Exemplo:

```bash
lua main.lua
```

### Opção 3: Usar o Terminal Externo

1. Abra o **Prompt de Comando** ou **PowerShell**
2. Navegue até a pasta do seu projeto:

```bash
cd D:\dev\VS\LUA
```

3. Execute o arquivo:

```bash
lua seu_arquivo.lua
```

---

## 📝 Exemplo de Uso

Crie um arquivo chamado `hello.lua`:

```lua
print("Olá, Mundo!")

local nome = "Lua"
print("Bem-vindo ao " .. nome .. "!")
```

**Para executar:**

- Pressione **Ctrl + Alt + N** (com Code Runner instalado)
- Ou use o terminal: `lua hello.lua`

---

## 🐛 Solução de Problemas

### "lua não é reconhecido como comando interno"

**Solução:**

- Verifique se o Lua foi adicionado ao PATH
- Reinicie o VS Code e o terminal após adicionar ao PATH
- Verifique se a pasta do Lua contém o arquivo `lua.exe`

### Code Runner não funciona

**Solução:**

1. Verifique se a extensão Code Runner está instalada
2. Verifique o `settings.json` conforme descrito acima
3. Reinicie o VS Code (Ctrl + Shift + P → "Reload Window")

### Erro: "Módulo não encontrado"

**Solução:**

- Certifique-se de que o arquivo `.lua` importado está no mesmo diretório
- Use caminhos relativos corretamente:
  ```lua
  require("./modulo")  -- mesmo diretório
  require("../modulo") -- diretório pai
  ```

### Encoding de Caracteres (Acentos não aparecem)

**Solução:**

1. Vá para **Arquivo** > **Preferências** > **Configurações**
2. Procure por "encoding"
3. Altere para `UTF-8`

---

## 📚 Recursos Adicionais

- [Documentação Oficial Lua](https://www.lua.org/manual/)
- [Lua 5.4 Reference Manual](https://www.lua.org/manual/5.4/)
- [Tutorial Lua em Português](https://www.lua.org/pil/)

---

## ✅ Checklist de Configuração

- [ ] Lua instalado e adicionado ao PATH
- [ ] Verificou `lua -v` no terminal
- [ ] Instalou a extensão Lua no VS Code
- [ ] Instalou a extensão Code Runner no VS Code
- [ ] Configurou `settings.json` com executorMap
- [ ] Testou executar um arquivo `.lua` simples
