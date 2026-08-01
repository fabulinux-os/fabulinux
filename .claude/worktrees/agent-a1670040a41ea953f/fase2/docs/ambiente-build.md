# Ambiente de build do Fabulinux (guia interno)

> Documento interno da equipe de build. O usuário final do Fabulinux **nunca** vê terminal —
> este guia é só para quem está montando o protótipo (Card #2, Fase 2).
>
> A base atômica final (Aurora, Kinoite, Bluefin ou Vanilla OS) ainda será decidida no **Card #1**.
> Este guia cobre a família **atômica + KDE** de forma que sirva independente da escolha — cada
> seção diz o que muda conforme a base.

## Visão geral do fluxo

```
Containerfile / recipe  →  build da imagem OCI  →  imagem de disco (qcow2/ISO)  →  boot na VM  →  screenshot  →  ajustar  →  repetir
```

Todas as bases candidatas (exceto Vanilla OS, ver nota abaixo) seguem o mesmo modelo **container
nativo em OSTree/bootc**: você parte de uma imagem base pronta (ex.: `ghcr.io/ublue-os/aurora:stable`
ou `quay.io/fedora/fedora-kinoite`), customiza num `Containerfile`, e o resultado é uma imagem OCI
que tanto pode ser instalada (rebase) num sistema já rodando quanto convertida em imagem de disco
para bootar do zero numa VM.

## 1. Requisitos de máquina

- **CPU:** virtualização por hardware habilitada na BIOS/UEFI (Intel VT-x ou AMD-V). Sem isso, a VM
  não boota uma base atômica com performance aceitável (nem o `bootc-image-builder` funciona bem,
  pois usa KVM internamente).
- **RAM:** 16 GB no host é o confortável (8 GB é o mínimo aceitável); reserve pelo menos 4 GB só
  para a VM.
- **Disco livre:** 60–100 GB. Imagens de container, camadas do build e os `.qcow2` gerados
  acumulam rápido (cada imagem de disco de teste fica entre 8–20 GB).
- **Host recomendado:** Linux (o GNOME Boxes só existe em Linux e usa KVM nativo — é a via mais
  simples). Em macOS/Windows, use **VirtualBox** (ou peça pro Hugo testar na parte Linux do setup
  dele — ver Card #10, que é responsabilidade dele).
- **Software necessário no host de build:** `podman` (ou `docker`), `git`, `qemu-img`. Em host
  Linux: `libvirt` + `virt-manager` ou GNOME Boxes.

## 2. Preparar a VM de teste

### 2.1 GNOME Boxes (recomendado em host Linux)

1. Instale: `flatpak install flathub org.gnome.Boxes` (ou pelo gerenciador de pacotes da distro).
2. Depois de gerar a imagem de disco (seção 3), abra o Boxes → **+** → **"Arquivo de máquina
   virtual"** → selecione o `.qcow2` gerado (ou o `.iso`, se a base distribuir instalador).
3. Antes de finalizar, clique em **Personalizar** para ajustar RAM (mín. 4 GB) e não deixar o
   Boxes redimensionar o disco (as imagens atômicas já vêm particionadas).
4. Se a VM não bootar (tela preta / cai no shell de recuperação): o Boxes usa firmware BIOS por
   padrão para alguns tipos de VM. Bases atômicas modernas esperam **UEFI**. Se o Boxes não expor
   essa opção na tela de criação, use `virt-manager` (mesmo motor libvirt, mais controle) para
   criar a VM manualmente com firmware **UEFI (OVMF)** e depois ela aparece automaticamente
   listada também no Boxes.

### 2.2 VirtualBox (multiplataforma — Linux, macOS, Windows)

1. Instale o VirtualBox (não precisa do Extension Pack para este uso).
2. **Nova VM** → Tipo: Linux → Versão: "Other Linux (64-bit)" (ou a variante Fedora/RH mais nova
   se aparecer na lista da sua versão do VirtualBox).
3. Em **Sistema → Placa-mãe**, marque **"Habilitar EFI (somente SO especiais)"** — obrigatório
   para bootar imagens atômicas/bootc.
4. Em **Sistema → Processador**, dê pelo menos 2–4 vCPUs; em **Sistema → Aceleração**, confirme
   que VT-x/AMD-V está habilitado (normalmente automático em host 64-bit).
5. RAM: mínimo 4 GB, disco: 40–64 GB.
6. Anexe o `.qcow2` gerado direto num controlador SATA (o VirtualBox lê `.qcow2` nativamente, sem
   converter).
7. Se o boot falhar por Secure Boot (imagem não assinada com a chave que a VM espera), desabilite
   Secure Boot no firmware da VM (tela azul do EFI ao bootar, ou `VBoxManage modifyvm <vm>
   --secureboot off`) — para teste interno isso é aceitável; o Card #1 decide como assinatura de
   imagem entra no pipeline oficial.
8. **Tire um snapshot logo após o primeiro boot bem-sucedido.** Isso vira o seu "estado limpo"
   para voltar rápido sem reinstalar quando um teste quebrar o sistema.

## 3. Ferramentas de build por base (o que muda conforme o Card #1 decidir)

Todas usam **Containerfile** (sintaxe Docker/Podman normal) como ponto de entrada. A diferença é
o tooling ao redor.

### 3.1 Se a base for Aurora (Universal Blue, KDE) — ou qualquer derivado ublue

- Duas vias, ambas oficiais:
  - **`ublue-os/image-template`** (mais próximo do metal): template com `Containerfile` +
    `Justfile`. Edite `image-template.env` (nome da imagem), aponte `FROM
    ghcr.io/ublue-os/aurora:stable` no Containerfile, coloque customizações em
    `build_files/build.sh`, e rode `just build`.
  - **BlueBuild** (mais declarativo): você escreve um `recipe.yml` (base, pacotes, arquivos,
    módulos) e ele gera o Containerfile e o workflow de CI automaticamente. Bom se quisermos que
    o pipeline de build rode no GitHub Actions sem manter Containerfile à mão.
- Repositório de referência: https://github.com/ublue-os/image-template

### 3.2 Se a base for Fedora Kinoite "pura" (sem camada Universal Blue)

- `Containerfile` com `FROM quay.io/fedora/fedora-kinoite:<versão>`, customizações via
  `rpm-ostree install` dentro do Containerfile.
- Para testar uma mudança dentro de uma VM Kinoite já rodando, sem gerar disco novo:
  `rpm-ostree rebase ostree-unverified-registry:<sua-imagem>` e reiniciar.

### 3.3 Se a base for Bluefin

- Bluefin oficialmente é a variante **GNOME** da Universal Blue; não existe uma variante KDE
  oficial dela hoje. Se o Card #1 optar por Bluefin mesmo assim, o caminho seria usar o
  `image-template` (seção 3.1) trocando o `FROM` pela imagem base do Bluefin e adicionar KDE por
  cima — bem mais trabalho manual que Aurora, que já entrega KDE pronto. Vale registrar isso como
  ponto contra Bluefin na decisão do Card #1.

### 3.4 Se a base for Vanilla OS (caminho diferente — não é bootc/rpm-ostree)

- Vanilla OS usa **ABRoot + Vib** (Vanilla Image Builder), não bootc/rpm-ostree. O recipe fica em
  `Vib` (`recipe.yml` próprio, módulos de build), a partir do template
  `Vanilla-OS/custom-image`. O workflow do GitHub Actions builda e publica a imagem OCI; depois
  você aponta o ABRoot da instalação para essa imagem (`abroot config-editor`, trocar `name` para
  o seu repositório).
- Vanilla OS distribui via **ISO instalável**, não via imagem de disco pronta tipo
  `bootc-image-builder`. Testar "do zero" significa instalar a ISO na VM, não só importar um
  `.qcow2`. Isso torna a iteração mais lenta — outro ponto a pesar no Card #1.

### 3.5 Gerando a imagem de disco para bootar do zero (bases bootc: Aurora/Kinoite/Bluefin)

Depois de ter a imagem OCI (local ou publicada), converta para `.qcow2` com o `bootc-image-builder`
oficial (`osbuild/bootc-image-builder`):

```bash
sudo podman run --rm -it --privileged --pull=newer \
  --security-opt label=type:unconfined_t \
  -v ./config.toml:/config.toml:ro \
  -v ./output:/output \
  -v /var/lib/containers/storage:/var/lib/containers/storage \
  quay.io/centos-bootc/bootc-image-builder:latest \
  --type qcow2 \
  localhost/fabulinux-proto:latest
```

- `config.toml` define usuário/senha inicial, partições, etc. (opcional; sem ele usa defaults).
- O resultado sai em `output/qcow2/disk.qcow2` — é esse arquivo que você importa no GNOME Boxes ou
  no VirtualBox (seção 2).
- Em host com SELinux enforcing, precisa do pacote `osbuild-selinux` instalado no host.

## 4. Iteração rápida (não regerar a VM inteira a cada mudança)

Regerar o `.qcow2` e reimportar na VM a cada ajuste de tema/config é lento. Use este loop, do mais
rápido ao mais lento:

1. **Mais rápido — inspecionar o container direto:** depois de `podman build -t
   local/fabulinux-test -f Containerfile .`, rode `podman run -it --rm local/fabulinux-test bash`
   e confira arquivos de config, temas, listas de Flatpak, etc. sem precisar bootar nada. Ótimo
   para checar se os arquivos foram parar no lugar certo.
2. **Meio-termo — atualizar uma VM que já está rodando:** suba um registry local (`podman run -d
   -p 5000:5000 --name registry registry:2`), publique sua imagem ali, e dentro da VM já
   existente rode `rpm-ostree rebase ostree-unverified-registry:<host>:5000/fabulinux-proto:latest`
   seguido de reboot. Evita regerar e reimportar disco a cada teste — só reaplica a camada nova.
3. **Mais lento — só quando precisa validar o boot do zero:** regenerar o `.qcow2` completo
   (seção 3.5) e reimportar na VM. Reserve isso para marcos (ex.: "primeiro boot", antes de pedir
   validação do Hugo), não para cada ajuste pequeno.
4. Use **snapshots** da VM (VirtualBox: Máquina → Tirar Instantâneo; libvirt/virt-manager:
   `virsh snapshot-create-as`) para voltar a um estado limpo em segundos em vez de reinstalar.

## 5. Capturando screenshots para validação

Precisamos de print da tela para validar tema, kiosk lock e identidade visual sem precisar de
acesso físico à VM.

- **De dentro do sistema convidado (mais fiel):** o KDE já vem com o **Spectacle** — captura e
  salva em arquivo. Se a VM tiver pasta compartilhada com o host, salve direto lá.
- **De fora, via host (funciona mesmo sem a UI carregar, útil pra depurar boot):**
  - libvirt/virt-manager: `virsh screenshot <nome-da-vm> saida.png` (opcional `--screen 0`).
  - VirtualBox: `VBoxManage controlvm "<nome-da-vm>" screenshotpng saida.png`.
  - GNOME Boxes não tem exportação de print própria na GUI — para automação, use `virsh` (mesmo
    backend libvirt) ou capture a janela do Boxes manualmente pelo host.
- Convenção sugerida: anexar os prints direto no PR/issue do card correspondente (ex.: comentário
  no Card #3 ao validar o tema de triângulos), nomeando `card-N-descrição.png`.

## 6. Checklist rápido

- [ ] Virtualização habilitada na BIOS do host de build.
- [ ] `podman`, `git`, `qemu-img` instalados no host.
- [ ] GNOME Boxes (Linux) **ou** VirtualBox com EFI habilitado pronto.
- [ ] Imagem OCI buildada localmente e inspecionada (`podman run ... bash`) antes de gerar disco.
- [ ] `.qcow2` gerado via `bootc-image-builder` (bases bootc) ou ISO instalada (Vanilla OS).
- [ ] Snapshot "estado limpo" tirado logo após o primeiro boot.
- [ ] Fluxo de screenshot testado (`virsh screenshot` ou `VBoxManage screenshotpng`).

## 7. Pendências de teste manual (Hugo)

- Este guia foi escrito com base em documentação oficial (Universal Blue, Red Hat/osbuild,
  GNOME/VirtualBox) mas **não foi executado numa máquina real** — não há VM disponível neste
  ambiente de build automatizado.
- Validar na prática: boot de fato de um `.qcow2` gerado pelo `bootc-image-builder` tanto no
  GNOME Boxes quanto no VirtualBox (o comportamento de UEFI/Secure Boot varia por versão de cada
  ferramenta).
- Assim que o Card #1 definir a base final, revisar este documento e **remover as seções das
  bases não escolhidas** (3.1–3.4), deixando só o caminho relevante.
- Card #10 (preparar a máquina/VM de teste, responsabilidade do Hugo) deve seguir este guia e
  reportar qualquer passo que não bateu com a realidade da máquina dele.
