# Escolha da base atômica/imutável — Fabulinux

> Card #1 (Fase 2). Compara quatro bases imutáveis com KDE Plasma e recomenda uma
> para servir de fundação técnica do Fabulinux. Orienta a decisão do card #9 (Hugo).

## Contexto e critérios

A arquitetura já está fechada no roadmap: **base imutável/atômica + KDE Plasma 6
travado (Kiosk) + apps via Flatpak**, com o SteamOS como referência de que essa
combinação funciona em produção. A pergunta deste card não é *se* vamos usar esse
modelo, mas **em cima de qual base concreta construir**.

Critérios avaliados para cada opção:

1. **Rollback/atomicidade** — maturidade e confiabilidade do mecanismo de update atômico.
2. **Base de apps e Flatpak** — Flathub habilitado, codecs, drivers, cobertura de hardware.
3. **Prontidão do KDE atômico** — o quão pronto/oficial é o suporte a Plasma 6 nessa base.
4. **Facilidade de brandizar e travar (Kiosk)** — quanto trabalho dá para trocar identidade
   visual e aplicar o KDE Kiosk framework.
5. **Esforço de manutenção** — o que sobra de trabalho recorrente para nós (rebase, CI, correções).
6. **Comunidade/documentação** — tamanho do projeto, atividade, qualidade da doc.
7. **Adequação a um público criativo iniciante** — "só funciona" logo no primeiro boot.

## As quatro opções

| | **Fedora Kinoite** | **Universal Blue Aurora** | **Bazzite (edição KDE)** | **Vanilla OS 2 (Orchid)** |
|---|---|---|---|---|
| **O que é** | Variante oficial do Fedora com KDE Plasma sobre OSTree (o "Kinoite" é ao Fedora Silverblue o que o KDE é ao GNOME) | Distro da comunidade Universal Blue, construída **em cima do Kinoite**, focada em workstation de produtividade | Distro da comunidade Universal Blue, construída **em cima do Kinoite**, focada em gaming/handhelds, mas com edição KDE "desktop" | Distro independente, base Debian Sid, com mecanismo próprio de atomicidade (ABRoot) |
| **Mecanismo de atomicidade** | `rpm-ostree` / `bootc` — o padrão histórico da família Fedora Atomic (Silverblue existe desde 2019) | Mesmo `rpm-ostree`/`bootc` do Kinoite, com camada de auto-update "zero manutenção" (staging automático, boot na próxima reinicialização) | Mesmo `rpm-ostree`/`bootc`, com ferramenta própria de rebase/rollback (`bazzite-rollback-helper`) | `ABRoot` — atualização A/B própria do projeto, tecnologia bem mais nova e com base trocada de Ubuntu para Debian na v2 (2024), ou seja, ainda instável em termos de rumo do projeto |
| **Flatpak/Flathub por padrão** | Vem com repositórios de terceiros **desativados** por padrão (é preciso habilitar Flathub explicitamente — passo simples e documentado) | Flathub **habilitado por padrão**, mais Homebrew/Linuxbrew e Distrobox como camadas extras, e app store própria ("Bazaar") | Flathub **habilitado por padrão**, com forte cobertura de codecs e drivers (NVIDIA, hardware de handheld, Asus, Surface) | Combina Flatpak com "Apx" (containers Ubuntu/Fedora/Arch/Alpine) — mais flexível, mas mais complexo, o oposto do "zero terminal" que buscamos |
| **Prontidão do KDE atômico** | Oficial, mantido pelo time Fedora KDE SIG, já em Plasma 6 | Plasma 6 com tema e UX já customizados; chamada pela imprensa de "a distro KDE mais polida disponível hoje" | Plasma 6.6 (2026), edição madura e testada em milhões de dispositivos (inclusive handhelds tipo Steam Deck) | **Não existe edição KDE.** Vanilla OS é GNOME-only — nunca lançaram nem anunciaram uma variante KDE |
| **Facilidade de brandizar/Kiosk** | Tela em branco: sem identidade visual pré-existente para remover, mas também sem ferramenta pronta de branding — o pipeline de imagem (Containerfile/BlueBuild) fica por nossa conta | Já usa o framework **BlueBuild** (recipe.yml) para se construir — é *forkável*, mas carrega opinião visual e de produto própria (Bazaar, painéis customizados) que precisaríamos desmontar | Também construída via BlueBuild, com guia de rebase oficial — porém a identidade é fortemente "gamer" (Steam, Gamescope, MangoHUD, emulação), exigindo poda pesada para não vazar essa estética | KDE Kiosk nem se aplica (não há KDE). Seríamos pioneiros numa combinação nunca testada por ninguém |
| **Esforço de manutenção recorrente** | Médio — herdamos o ciclo de ~13 meses do Fedora e cuidamos do próprio pipeline de imagem, mas sem lixo de terceiros para remover a cada sync | Baixo se consumirmos a imagem-base `kinoite-main` (mesma usada pela Aurora) direto, ou médio se formos além e seguirmos a Aurora como fork (precisa reconciliar branding a cada rebase) | Baixo tecnicamente (comunidade grande resolve bugs rápido), mas alto em "poda" — cada rebase upstream tende a reintroduzir pacotes/ajustes de gaming que teríamos que remover de novo | Alto — o projeto já trocou de base uma vez (Ubuntu → Debian) e de ferramenta de pacotes (Apx v1 → v2); sinal de instabilidade de rumo |
| **Comunidade/documentação** | Enorme: é o próprio Fedora — Fedora Magazine, wiki, fóruns, milhões de usuários indiretos via Silverblue/Kinoite | Pequena: ~717 estrelas no GitHub, projeto novo (2024), time voluntário reduzido | Grande: ~8.600+ estrelas no GitHub, projeto listado na Linux Foundation Insights, documentação extensa em docs.bazzite.gg | Pequena e nichada: ABRoot/Apx são tecnologias específicas do projeto, sem o mesmo volume de doc/comunidade que rpm-ostree + Flatpak |
| **Adequação ao público criativo iniciante** | Neutra: exige que nós entreguemos os "temperos" (codecs, drivers, Flathub) que outras bases já trazem prontos | Boa: já resolve codecs/multimídia e tem UX polida — reduz nosso trabalho de integração | Boa em hardware (grande cobertura de drivers/laptops), mas identidade visual/gamer é o oposto do tom "elegante, criativo" do Fabulinux | Ruim: sem KDE, o critério mais básico do projeto já não é atendido |

### Uma observação importante que muda o enquadramento

Tanto a **Aurora** quanto a **Bazzite** não são bases "originais": as duas são
construídas **em cima do Fedora Kinoite**, usando como fundação comum a imagem
`ublue-os/main` (especificamente a variante `kinoite-main`, que já adiciona codecs
multimídia não-livres sobre o Kinoite puro). Ou seja, a pergunta real não é
"Kinoite vs. Aurora vs. Bazzite vs. Vanilla OS" como quatro fundações
equivalentes — é **"Kinoite" como a raiz técnica comum, com Aurora e Bazzite como
dois exemplos prontos (e já opinativos) de como transformá-lo em produto**.

O framework que ambas usam para isso, o **BlueBuild** (`recipe.yml` + GitHub
Actions), é hoje o caminho oficialmente recomendado pela própria comunidade
Universal Blue para qualquer pessoa construir sua própria imagem customizada a
partir do Kinoite — exatamente o nosso caso.

## Recomendação

**Construir o Fabulinux como uma imagem própria via BlueBuild, usando a imagem-base
`ghcr.io/ublue-os/kinoite-main` (Fedora Kinoite + codecs) como fundação — não
herdar diretamente a Aurora nem a Bazzite como produto final.**

Por quê:

- **Caminho oficialmente suportado.** BlueBuild + Kinoite é a mesma receita que a
  Universal Blue documenta para qualquer criador de distro customizada, e é
  literalmente como Aurora e Bazzite são feitas — não é gambiarra nem fork por fora
  do ecossistema.
- **Tela em branco de marca.** Diferente de partir da Aurora (que já tem identidade
  visual própria, app store "Bazaar" e painéis customizados) ou da Bazzite (estética
  fortemente "gamer"), partir do Kinoite/`kinoite-main` significa que **não temos
  nada para desmontar** antes de aplicar a identidade do Fabulinux (tema de
  triângulos, paleta ametista/navy, Kiosk). Menos trabalho de "subtrair", mais
  controle sobre o resultado final.
- **`kinoite-main` já resolve a maior dor.** Herdamos os codecs multimídia e ajustes
  de compatibilidade que a Aurora e a Bazzite também usam como ponto de partida —
  não estamos abrindo mão do "batteries included", só da camada de produto/branding
  que vem por cima.
- **KDE Kiosk é o caminho oficial de trava**, documentado pelo próprio KDE
  (`develop.kde.org/docs/administration/kiosk`) e independente da distro por baixo —
  funciona igual em Kinoite puro ou em qualquer derivado.
- **Rollback maduro.** `rpm-ostree`/`bootc` é a tecnologia mais testada das quatro
  (base da família Fedora Atomic desde 2019, e é o que roda por baixo tanto da
  Aurora quanto da Bazzite).
- **Vanilla OS está fora.** Não existe variante KDE — desqualifica de cara o
  critério mais básico do projeto. Além disso, o projeto trocou de base (Ubuntu →
  Debian) e de ferramenta de pacotes (Apx v1 → v2) recentemente, um sinal de
  instabilidade de rumo que não queremos herdar.

### Riscos da recomendação (para o teste manual do Hugo)

1. **Perdemos o "para-choque" de comunidade da Aurora/Bazzite.** Elas já testam
   drivers, hardware exótico e bugs de KDE Kiosk em escala antes de nós. Partindo
   do Kinoite puro, seremos os primeiros a pisar em alguns problemas — mitigar
   testando em pelo menos 2-3 perfis de hardware (notebook comum, notebook com
   GPU NVIDIA) antes da primeira ISO pública.
2. **Cobertura de hardware é nossa responsabilidade.** Sem o trabalho de driver
   que a Bazzite faz (Asus, Surface, handhelds), pode faltar suporte de fábrica em
   laptops incomuns. Mitigar com RPM Fusion + `kinoite-main` e revisão de hardware
   antes do lançamento.
3. **Pipeline de imagem (BlueBuild) por nossa conta.** Precisamos manter o
   `recipe.yml`, a Action de build/rebase e a assinatura da imagem — trabalho que a
   Aurora/Bazzite já fazem por si. Mitigar reaproveitando os templates públicos
   (`ublue-os/image-template`) como ponto de partida, em vez de escrever do zero.
4. **KDE Kiosk em Plasma 6 precisa de validação prática.** A documentação oficial
   existe, mas exemplos de "distro inteira travada" são mais raros que exemplos de
   TI corporativa travando uma máquina. **Isto precisa de teste manual em VM/hardware
   pelo Hugo** antes de considerarmos o Kiosk "pronto".
5. **Sem Flathub habilitado por padrão no Kinoite puro** — é preciso adicionar o
   remoto Flathub explicitamente na receita da imagem. Passo simples e documentado,
   mas é fácil esquecer e "quebrar" a loja de apps no primeiro boot se não for
   testado.

### Alternativa de plano B (se decidirmos não manter um pipeline de imagem próprio)

Se, na decisão do card #9, o Hugo preferir **minimizar esforço de engenharia** em
vez de maximizar controle de marca, a segunda opção recomendada é **fazer fork da
Aurora** (mesma linhagem Kinoite, UX já polida, comunidade pequena mas ativa) e
reskinar por cima — aceitando o trabalho extra de remover a identidade visual e a
loja de apps "Bazaar" da Aurora. A Bazzite fica como terceira opção (maior
comunidade e cobertura de hardware do grupo), mas exigiria a poda mais pesada por
causa do forte viés de gaming. A Vanilla OS não é uma alternativa viável enquanto
não lançar (se lançar) uma edição KDE.

## Fontes consultadas

- [Fedora Atomic Desktops — Kinoite](https://fedoraproject.org/atomic-desktops/kinoite/)
- [Discover Fedora Kinoite — Fedora Magazine](https://fedoramagazine.org/discover-fedora-kinoite/)
- [Universal Blue](https://universal-blue.org/)
- [Aurora — getaurora.dev](https://getaurora.dev/en/) e [docs.getaurora.dev](https://docs.getaurora.dev/)
- [Aurora é o lado KDE da Bluefin — XDA Developers](https://www.xda-developers.com/aurora-is-the-kde-side-of-bluefin-and-it-might-be-the-most-polished-linux-desktop-right-now/)
- [Comparação Bazzite vs. Fedora Atomic — docs.bazzite.gg](https://docs.bazzite.gg/General/Fedora_Atomic_Comparison/)
- [Bazzite — updates, rollbacks e rebase — docs.bazzite.gg](https://docs.bazzite.gg/Installing_and_Managing_Software/Updates_Rollbacks_and_Rebasing/)
- [Discussão Aurora vs. Bazzite KDE — Universal Blue Discourse](https://universal-blue.discourse.group/t/question-about-aurora-vs-bazzite-kde/11230)
- [Vanilla OS 2: an immutable distribution to run all software — LWN.net](https://lwn.net/Articles/989629/)
- [Apx, an unconventional package manager — blog oficial Vanilla OS](https://vanillaos.org/blog/article/2023-01-28/apx-an-unconventional-package-manager)
- [ABRoot — pkg.go.dev](https://pkg.go.dev/github.com/vanilla-os/abroot)
- [BlueBuild — Building on Universal Blue](https://blue-build.org/learn/universal-blue/)
- [BlueBuild — template oficial `ublue-os/image-template`](https://github.com/ublue-os/image-template)
- [Introduction to KDE Kiosk — develop.kde.org](https://develop.kde.org/docs/administration/kiosk/introduction/)
- [KDE Kiosk keys — develop.kde.org](https://develop.kde.org/docs/administration/kiosk/keys/)
- [Fedora Remix/Rebrand Guidelines — Fedora Project Wiki](https://fedoraproject.org/wiki/Legal/TrademarkGuidelines)
