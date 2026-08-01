# NOTAS — Card #17: pipeline BlueBuild + build de ISO

## O que foi feito

```
fase2/bluebuild/recipes/recipe.yml   # receita BlueBuild
fase2/bluebuild/disk_config/iso.toml # config do bootc-image-builder p/ a ISO
.github/workflows/build.yml          # builda a imagem e publica em ghcr
.github/workflows/build-iso.yml      # gera a ISO a partir da imagem publicada
```

A receita parte de `ghcr.io/ublue-os/kinoite-main` (Fedora Kinoite + KDE Plasma
6, decidido em `fase2/docs/escolha-base.md`) e implementa, nesta ordem, os
módulos de `fase2/docs/decisoes-produto.md`:

1. **Imutabilidade forte** — não implementada por nenhum módulo aqui, de
   propósito: composefs + fs-verity e o modo somente-leitura já vêm ativados
   por padrão no `kinoite-main` (padrão da família Fedora Atomic). Nenhum
   módulo da receita desativa isso, e tudo roda em build-time — o usuário
   nunca faz layering na imagem viva.
2. **Codecs + VLC** — dois módulos `rpm-ostree`: primeiro habilita RPM Fusion
   free/nonfree (instala as "-release" RPMs), depois troca `ffmpeg-free` →
   `ffmpeg` completo, `mesa-va-drivers`/`mesa-vdpau-drivers` → variantes
   "freeworld" (aceleração VA-API/VDPAU), instala os plugins GStreamer
   good/bad/ugly/libav e o VLC.
3. **Flatpaks padrão** — módulo `default-flatpaks` com os 21 IDs de
   `fase2/flatpak/apps.list` (card #6, PR #13 — **ainda não mergeado em
   `main`** no momento em que este card foi escrito; os IDs foram copiados
   manualmente para a receita. Se o card #6 mudar algum ID antes do merge,
   **sincronizar aqui também**). Os apps pesados de vídeo/3D (Blender,
   Kdenlive, OBS Studio, HandBrake) ficam de fora do `install:` por padrão —
   tier mínimo é 2 núcleos/4 GB (decisoes-produto.md, seção 4) — mas continuam
   instaláveis a qualquer momento pela loja de apps, já que o Flathub é
   habilitado pelo próprio módulo.
4. **Drivers de terceiros** — firmware comum já vem embutido no `kinoite-main`
   (linux-firmware + Mesa de fábrica). A variante NVIDIA e o escape hatch de
   akmods **não entraram nesta receita** — ver TODO abaixo.
5. **Build de ISO** — `build-iso.yml` usa o `osbuild/bootc-image-builder-action`
   (o mesmo mecanismo do template oficial `ublue-os/image-template`) para
   gerar uma ISO Anaconda a partir da imagem publicada em ghcr, com um
   kickstart que já faz `bootc switch` para a imagem do Fabulinux assim que a
   instalação termina.

## Sem segredo nenhum no primeiro build (cosign é TODO do Hugo)

De propósito, **nem a receita nem os workflows têm nada de cosign**:

- A receita não tem o módulo `type: signing`.
- `build.yml` não passa `cosign_private_key`/`cosign_public_key` para a
  action `blue-build/github-action` (esses inputs aparecem como
  `required: true` na documentação da action, mas isso não é validado pelo
  runtime do GitHub Actions para actions normais — só vale para reusable
  workflows via `workflow_call`. Testado/confirmado lendo o `action.yml`
  publicado em `blue-build/github-action`: o valor simplesmente fica vazio se
  o input não for passado, e o build segue sem assinar).
- `build-iso.yml` só faz `podman pull`/build da imagem já publicada — não
  verifica assinatura nenhuma.

Isso significa que o **primeiro `git push` para `main` já deve buildar e
publicar a imagem em ghcr, e já deve ser possível gerar a ISO**, sem o Hugo
precisar cadastrar nenhum secret antes.

### TODO do Hugo — ativar assinatura cosign
1. Gerar o par de chaves: `cosign generate-key-pair` (ou usar o botão
   "Setup cosign" do BlueBuild, ver <https://blue-build.org/how-to/cosign/>).
2. Cadastrar os secrets do repositório: `COSIGN_PRIVATE_KEY` (conteúdo da
   chave privada) e `COSIGN_PUBLIC_KEY` (conteúdo da chave pública).
3. Em `.github/workflows/build.yml`, dentro do step "Build imagem
   customizada", descomentar/adicionar:
   ```yaml
   cosign_private_key: ${{ secrets.COSIGN_PRIVATE_KEY }}
   cosign_public_key: ${{ secrets.COSIGN_PUBLIC_KEY }}
   ```
4. Em `fase2/bluebuild/recipes/recipe.yml`, adicionar de volta o módulo:
   ```yaml
   - type: signing
   ```
   (isso configura a política de verificação de assinatura na própria
   imagem — sem a chave configurada nos passos 1-3, esse módulo bloquearia
   `rpm-ostree rebase`/pulls por exigir uma assinatura que não existe).
5. Commitar o `cosign.pub` gerado no passo 1 na raiz de `fase2/bluebuild/`
   (chave pública, não é segredo) — a action usa esse arquivo se ele já
   existir no repo.

## TODO — variante NVIDIA (não coube neste card)

**Estratégia recomendada** (documentando para não perder o fio, decisoes-
produto.md seção 3): criar um **segundo recipe** em
`fase2/bluebuild/recipes/recipe-nvidia.yml`, com a única diferença sendo a
`base-image`:

```yaml
base-image: ghcr.io/ublue-os/kinoite-nvidia-main   # em vez de kinoite-main
```

O resto da receita (RPM Fusion, codecs, VLC, Flatpaks) pode ser **igual** —
dá para fatorar o conteúdo comum num arquivo à parte e usar `from-file` nos
dois recipes, ou simplesmente manter os dois arquivos em paralelo por
enquanto (mais simples, mais duplicação — trade-off para o Hugo decidir).
Isso exigiria também:
- Adicionar `recipe-nvidia.yml` à matrix do `build.yml` (`matrix.recipe`).
- Um segundo job/matrix em `build-iso.yml` (ou uma segunda ISO) para a
  variante NVIDIA, com seu próprio `iso.toml` apontando o kickstart para
  `ghcr.io/fabulinux-os/fabulinux-nvidia:latest`.
- Decidir o nome de publicação da imagem NVIDIA em ghcr (sugestão:
  `fabulinux-nvidia`, mesmo padrão do ublue: `<nome>` vs `<nome>-nvidia`).

**Escape hatch de akmods** (para hardware fora do comum, sem esperar a
variante NVIDIA): documentar para o usuário final, fora desta receita, o
comando que o próprio Fedora Atomic/ublue já suporta:
```bash
sudo rpm-ostree install <pacote-akmods-do-driver>
sudo systemctl reboot
```
Isso é layering atômico e reversível (`rpm-ostree rollback` desfaz), a
exceção controlada mencionada em decisoes-produto.md seção 3 — não precisa de
nada novo no pipeline, só documentação de usuário (fora do escopo deste
card; sugestão: entra na wiki/site do Fabulinux, não na receita).

## Como disparar o build

1. Fazer merge deste PR em `main` (ou rodar manualmente pela aba Actions —
   ambos os workflows têm `workflow_dispatch`).
2. **Build.yml roda primeiro** (build da imagem): Actions → "build-fabulinux-image"
   → "Run workflow", ou espera o gatilho automático em push para `main`.
   Publica em `ghcr.io/fabulinux-os/fabulinux:latest` (ou a tag do commit/PR).
3. **Build-iso.yml roda depois** (precisa da imagem já publicada no passo 2):
   dispara sozinho via `workflow_run` quando o build.yml terminar com
   sucesso em `main`, ou manualmente pela aba Actions.

## Onde baixar a ISO

Depois do `build-iso.yml` terminar: GitHub → aba **Actions** → o run do
workflow "build-fabulinux-iso" → seção **Artifacts**, no final da página do
run → baixar `fabulinux-iso` (fica disponível por 30 dias).

Isso é um artefato de workflow, não uma GitHub Release — mais simples para o
primeiro build funcionar sem nenhuma configuração extra. Se o Hugo preferir
uma Release pública e permanente (link fixo, sem expirar em 30 dias), trocar
o último step de `build-iso.yml` (`actions/upload-artifact`) por
`softprops/action-gh-release` — não fiz essa troca agora para não introduzir
mais uma decisão de produto (nome/formato da release) sem aprovação.

## O que o Hugo precisa validar/testar (não dá para testar aqui, sem Linux/VM)

1. **O build em si.** Nunca rodou de ponta a ponta — é a primeira vez que
   esta receita builda. Prováveis pontos de atrito num primeiro run real:
   - Nomes de pacote RPM Fusion/GStreamer (`gstreamer1-plugins-*-freeworld`
     etc.) foram escritos a partir do conhecimento do guia oficial "RPM
     Fusion — Howto/FFmpeg" e de receitas BlueBuild equivalentes, **mas não
     foram conferidos ao vivo contra o repositório RPM Fusion do Fedora 42**
     (sem acesso a `dnf`/VM Fedora neste ambiente). Se algum nome tiver
     mudado, o módulo 2 de codecs falha — o log do Actions vai apontar
     exatamente qual pacote não foi encontrado.
   - `image-version: 42` — conferir se é a versão atual do `kinoite-main` no
     momento do merge (ele segue o ciclo do Fedora, ~13 meses).
2. **A ISO gerada.** Baixar, testar em VM (ou pendrive) que o instalador
   Anaconda sobe, particiona, instala, e que o `bootc switch` do kickstart
   deixa o sistema já na imagem certa no primeiro boot.
3. **`fase2/flatpak/apps.list` (card #6).** Quando o PR #13 for mergeado,
   conferir se os IDs continuam batendo com os copiados aqui na receita.
4. **Ordem build → ISO.** Confirmar que o `workflow_run` do `build-iso.yml`
   realmente dispara depois do `build.yml` (nome do workflow em
   `workflows: ["build-fabulinux-image"]` precisa continuar batendo com o
   `name:` de `build.yml` caso algum dos dois seja renomeado no futuro).
5. **Cosign** — ver TODO acima; sem isso, a imagem/ISO funcionam mas ficam
   sem assinatura verificável (aceitável para o protótipo da Fase 2, não
   para uma release pública).
6. **Variante NVIDIA** — ver TODO acima; não entrou nesta entrega.

## Suposições

- O `default-flatpaks` module do BlueBuild não exige nenhum pacote adicional
  (ex. Nushell) além do que já vem no `kinoite-main` — os demais módulos
  ublue já dependem de Nushell para outras finalidades, então a suposição é
  que ele já vem de fábrica; não foi possível confirmar isso rodando o build
  de verdade.
- Pacotes ghcr publicados por este repositório ficam com visibilidade que o
  `GITHUB_TOKEN` padrão consegue ler dentro do próprio workflow (necessário
  para o `build-iso.yml` puxar a imagem). Se a organização tiver alguma
  política mais restritiva de visibilidade de pacotes, pode ser preciso
  ajustar a visibilidade do pacote em Settings → Packages depois do primeiro
  build.
