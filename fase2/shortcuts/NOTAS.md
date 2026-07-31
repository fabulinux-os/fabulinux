# Card #7 — Atalhos estilo Mac (⌘) no KDE Plasma 6

## Resumo do que cada arquivo faz

| Arquivo | O que resolve | Nível |
|---|---|---|
| `kglobalshortcutsrc` | ⌘+Espaço (busca/lançador) e ⌘+Tab / ⌘+Shift+Tab (troca de janelas), + bônus opcional (toque isolado em ⌘ abre a Visão Geral) | 100% KDE, oficial, sem risco |
| `keyd-mac-modifiers.conf` | ⌘+C / ⌘+V / ⌘+X / ⌘+Z (e opcionalmente ⌘+A / ⌘+S / ⌘+F) funcionando como Ctrl dentro de qualquer app | Serviço de sistema à parte (keyd), fora do KDE |

Os dois são **independentes** — dá para usar só o primeiro (mais simples e seguro) ou os dois juntos (experiência mais completa).

## Por que isso não é só um arquivo do KDE (a parte honesta)

O KDE tem um sistema de **atalhos globais** (`kglobalaccel`) que decide o que
acontece quando nenhum app "dono" do foco já consumiu a tecla — é isso que
`kglobalshortcutsrc` controla, e é exatamente por isso que dá para mapear
⌘+Espaço → KRunner e ⌘+Tab → troca de janelas de forma limpa: são ações do
**ambiente** (KWin/KRunner), não de um app qualquer.

Copiar/colar (Ctrl+C/V/X/Z) é diferente: é o **próprio app** (o toolkit dele —
Qt, GTK, Electron, o terminal) que decide "quando vir Ctrl+C, copio". Isso é
hardcoded em milhares de aplicativos e não existe um único arquivo de config
do KDE que reescreva "o que Ctrl+C significa" para todo mundo. Duas saídas
honestas, com trade-offs reais:

### Opção A (entregue) — `keyd`, remapear no nível do teclado

O `keyd` lê o evento do teclado antes de ele chegar ao Wayland/X11 — ou seja,
para o resto do sistema, quando alguém aperta ⌘+C, o que sai do teclado já é
literalmente **Ctrl+C**. Nenhum app precisa saber que existe uma tecla ⌘;
funciona igual em Konsole, Firefox, VS Code, GIMP, etc.

Riscos e limites reais:
- É um **daemon rodando como serviço de sistema** com acesso a `/dev/input/*`
  (grupo `keyd`/`input`), não um dotfile do usuário. Um erro de config pode,
  na pior hipótese, deixar o teclado maluco até reiniciar o serviço — por
  isso o passo de teste abaixo pede para testar em uma sessão descartável
  antes de aplicar de fábrica.
- Numa base **imutável/atômica** (o que o card #9 ainda vai decidir), o
  `keyd` precisa ser empacotado *na imagem* (camada do sistema, não Flatpak —
  Flatpak não tem acesso a `/dev/input`). Isso é uma dependência entre este
  card e a decisão da base atômica.
- Só remapeamos C/V/X/Z (+A/S/F opcionais) dentro da camada `[meta]`. Se
  algum app já usar ⌘+alguma-dessas-teclas para outra coisa dentro do
  próprio KDE (raro, mas possível em apps de terceiros), o remapeamento
  no teclado tem prioridade — vale revisar caso a caso.
- Layouts de teclado não-US podem exigir ajuste fino (relatado por usuários
  com layout espanhol, por exemplo) — testar com o layout real do teclado
  do Fabulinux antes de assumir que está 100%.

### Opção B (documentada, não entregue como arquivo) — trocar Ctrl ↔ Super via XKB

Existe uma opção padrão do X11/XKB chamada `ctrl:swap_lwin_lctl`, que troca
fisicamente o que a tecla Ctrl e a tecla Super/Win enviam. Ative por:
- GUI: **Configurações do Sistema → Dispositivos de Entrada → Teclado →
  Avançado**, grupo "Posição da tecla Ctrl" (Ctrl key position) — o KDE lista
  cerca de 13 variações desse tipo de troca ali.
- Ou gravando direto: `kwriteconfig6 --file kxkbrc --group Layout --key
  Options "ctrl:swap_lwin_lctl"` (some com outras opções existentes,
  separadas por vírgula, se já houver alguma).

Por que **não** escolhemos isso como entrega principal:
- É uma troca **total e cega**: a tecla que virar "Ctrl" passa a valer Ctrl
  para tudo, inclusive `Ctrl+C` do terminal (interromper processo), e a
  tecla que virar "Super" passa a disparar ⌘+Espaço/⌘+Tab a partir de onde
  fisicamente ficava o Ctrl (canto inferior esquerdo) — nada parecido com a
  posição do Cmd no teclado de um Mac.
- Não dá pra ter "⌘+C vira Ctrl+C" **e** "⌘+Espaço continua sendo ⌘+Espaço"
  ao mesmo tempo com essa técnica, porque ela troca a tecla inteira, não
  tecla-por-combinação. O `keyd` (Opção A) consegue os dois porque trabalha
  por camada/combinação, não por troca cega de tecla.
- É mais simples de aplicar (não exige instalar nada, é só XKB), então vale
  como **plano B** para uma sessão X11 sem o pacote `keyd` disponível, mas
  não é o que recomendamos de fábrica.

## Como aplicar para testar (Hugo, isto é o roteiro pendente)

1. **Atalhos KDE nativos** (`kglobalshortcutsrc`):
   - Copie as seções para `~/.config/kglobalshortcutsrc` (mescle nas seções
     `[org.kde.krunner.desktop]` e `[kwin]` já existentes — não sobrescreva
     o arquivo inteiro, para não perder outros atalhos já configurados) ou,
     para valer para todo usuário novo, em `/etc/xdg/kglobalshortcutsrc`.
   - Alternativa sem editar arquivo à mão, comando a comando:
     ```
     kwriteconfig6 --file kglobalshortcutsrc --group org.kde.krunner.desktop \
       --key _launch "Alt+Space\tAlt+F2\tMeta+Space,Alt+Space\tAlt+F2\tMeta+Space,KRunner"
     kwriteconfig6 --file kglobalshortcutsrc --group kwin \
       --key "Walk Through Windows" "Alt+Tab\tMeta+Tab,Alt+Tab\tMeta+Tab,Walk Through Windows"
     ```
   - **Aplicar sem logout**: abra Configurações do Sistema → Atalhos, mude
     qualquer coisa (ativa o botão "Aplicar") e clique Aplicar — isso força
     o `kglobalaccel` a reler o arquivo. Só editar o arquivo não é
     suficiente em todos os casos; na dúvida, faça logout/login.
   - Teste: ⌘+Espaço deve abrir o KRunner; ⌘+Tab deve abrir o alternador de
     janelas; ⌘+Shift+Tab deve percorrer em ordem reversa.
   - **Se a base ficar em Plasma 6.0.x** (antes do 6.1): o atalho de "só a
     tecla ⌘" (bloco `Overview` marcado como bônus) precisa ir para
     `kwinrc`, seção `[ModifierOnlyShortcuts]`, chave `Meta=...` (formato
     antigo, baseado em D-Bus) em vez de `kglobalshortcutsrc`. Como o card
     #9 ainda não fechou a base/versão, o arquivo aqui assume 6.1+; se sair
     uma versão mais antiga, avise que ajustamos.

2. **`keyd` para ⌘+C/V/X/Z**:
   - Instale o pacote `keyd` (nome do pacote muda por distro/base).
   - `sudo cp fase2/shortcuts/keyd-mac-modifiers.conf /etc/keyd/default.conf`
   - `sudo systemctl enable --now keyd`
   - Teste **num app não-KDE também** (ex.: um navegador), para confirmar
     que o remapeamento é de fato global e não só dentro de apps Qt:
     selecione um texto, ⌘+C, clique em outro campo, ⌘+V — deve colar.
   - Se algo sair errado, `sudo systemctl stop keyd` devolve o teclado ao
     normal imediatamente (sem precisar reiniciar a máquina).

3. **Pendências de teste manual (não dá para validar sem hardware/VM aqui)**:
   - Confirmar a versão exata do Plasma que a base atômica final (card #9)
     vai trazer, para saber se o bloco `Overview` (toque isolado em ⌘) usa a
     sintaxe 6.1+ deste arquivo ou precisa migrar para `kwinrc` (6.0.x).
   - Confirmar se `keyd` está disponível/empacotável na base atômica
     escolhida (e como injetá-lo na imagem imutável — layer do OSTree, ou
     equivalente).
   - Testar em teclado ABNT2/PT-BR real (acentos, `~`, `Meta+Shift+Tab`) —
     os exemplos de layouts não-US no `keyd` mostraram que combinações
     podem precisar de ajuste fino.
   - Confirmar visualmente no Painel de Controle (Atalhos Globais) que os
     novos atalhos aparecem certos e não colidem com nada já configurado
     nos outros cards da Fase 2 (kiosk, tema, etc.).
