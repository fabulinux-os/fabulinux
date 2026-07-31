# NOTAS — Card #6: Lista de Flatpaks + script de pré-instalação

## O que tem aqui
- `apps.list` — 21 Application IDs do Flathub, um por linha, agrupados por categoria em comentários.
- `install-apps.sh` — script idempotente que garante o remote `flathub` e instala cada ID da lista via `flatpak install`.

Todos os IDs foram conferidos manualmente na página de cada app no Flathub (flathub.org) em 2026-07-31, via WebSearch/WebFetch — não foram assumidos de memória.

## Casos especiais

### DaVinci Resolve (Blackmagic Design)
**Não está no Flathub.** Não existe pacote oficial nem da Blackmagic nem da comunidade Flathub (há apenas repositórios de terceiros não oficiais, ex. `pobthebuilder/resolve-flatpak`, fora do Flathub e sem garantia de manutenção/segurança — não recomendado para uma distro travada/curada como o Fabulinux).

Alternativa: o Resolve é distribuído pela Blackmagic como instalador `.run` proprietário, mediante cadastro gratuito no site deles. Para o Fabulinux isso significa:
- **Curto prazo:** não entra na pré-instalação automática. Documentar no site/wiki do Fabulinux como "instalação manual opcional" (baixar o `.run` oficial e rodar fora do fluxo Flatpak), fora do escopo deste card.
- **Alternativa nativa em Flatpak** já coberta pela curadoria: **Kdenlive** (`org.kde.kdenlive`) cobre o caso de uso de edição de vídeo dentro do modelo 100% Flatpak/imutável.
- Se no futuro a Blackmagic publicar um Flatpak oficial, só adicionar o ID em `apps.list`.

### Gerenciador de fontes
Escolhido **`org.gnome.FontManager`** (Font Manager), não `org.gnome.font-viewer`. Motivo: o pedido da curadoria é "gerenciador" (instalar/ativar/desativar/organizar famílias), o Font Manager cobre isso; o `font-viewer` do GNOME é só visualizador de preview, sem gestão de instalação.

### Áudio pro (Ardour) vs. base gratuita
O flatpak oficial do Ardour (`org.ardour.Ardour`) instala normalmente, mas o Ardour usa modelo "pague o que quiser / recompile" — sem pagamento, o app roda com um lembrete de doação e sem os builds otimizados. Isso é comportamento do próprio app, não do empacotamento Flatpak; não há nada a mudar no script por causa disso, só avisar o time de conteúdo/onboarding.

## Como testar (Hugo / QA)
Não há VM Linux disponível neste ambiente de build, então o script não foi executado de ponta a ponta contra o Flathub real. Foi validado:
1. `bash -n fase2/flatpak/install-apps.sh` — sintaxe OK.
2. Execução contra um `flatpak` mock (script fake que simula `remote-add`/`info`/`install`) para validar o fluxo: parsing de `apps.list` (21 IDs lidos corretamente), detecção de "já instalado" (pula), detecção de falha de instalação (reporta e sai com código 1), e o resumo final (instalados/já presentes/falharam).

Passos para testar em máquina/VM Linux real com Flatpak instalado:
```bash
# dry-run primeiro, só para conferir a lista sem baixar nada:
./fase2/flatpak/install-apps.sh --dry-run

# instalação real, escopo do usuário (não precisa de root, bom para teste rápido):
FLATPAK_INSTALLATION=user ./fase2/flatpak/install-apps.sh

# instalação real, escopo do sistema (o modo pensado para o build da imagem, exige root):
sudo ./fase2/flatpak/install-apps.sh

# rodar de novo para confirmar idempotência (tudo deve aparecer como "já instalado"):
sudo ./fase2/flatpak/install-apps.sh
```
Confirmar ao final que `flatpak list` mostra os 21 apps e que nenhum ficou faltando.

## Suposições
- O script assume que o pacote `flatpak` (o runtime) já está presente na imagem base antes de rodar — este card cobre só a curadoria de apps, não a instalação do próprio Flatpak.
- Instalação padrão é `--system` (pensada para rodar durante o build/provisionamento da imagem imutável, como root/chroot). `--user` existe só para permitir testar a lista numa sessão comum sem root.
- Todos os 21 IDs foram verificados como existentes no Flathub na data acima; não foi verificado se cada um tem build para todas as arquiteturas (ex. arm64) — se o Fabulinux mirar ARM, isso precisa ser conferido à parte.

## Riscos
- Flathub pode remover, renomear ou "unlist" um app entre a verificação e o build real (raro, mas aconteceu com apps individuais no passado). Recomenda-se rodar o script (mesmo que em `--dry-run`) como parte do pipeline de CI/build para pegar isso cedo.
- Alguns apps (ex. Audacity, RawTherapee) aparecem como "unverified"/mantidos pela comunidade Flathub, não pelo desenvolvedor original — isso é normal no ecossistema Flatpak, mas vale nota se o Fabulinux quiser badge de "app verificado" na loja/curadoria.
