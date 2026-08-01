# Decisões de produto — Fabulinux (Fase 2)

Registro das decisões que orientam a receita da imagem. Aprovadas por Hugo em 2026-08-01.

## 1. Imutabilidade — "quanto mais imutável melhor"

Objetivo: máxima robustez para o usuário, mantendo a manutenção viável.

- Base só-leitura (`rpm-ostree`/`bootc`), atualizações **atômicas com rollback**.
- **Integridade selada:** composefs + fs-verity (padrão no Fedora Atomic recente).
- **Sem layering em runtime pelo usuário:** o usuário nunca altera o sistema vivo.
  Toda mudança acontece via **receita + rebuild** (rebase atômico).
- **Apps do usuário sempre via Flatpak** (userspace) — nunca tocam a base.

> Modelo SteamOS: imutável de verdade para o usuário; porta de manutenção só pela receita.

## 2. Multimídia / codecs (compatibilidade máxima)

- Partir de `ghcr.io/ublue-os/kinoite-main` (já traz codecs) e reforçar com **RPM Fusion**:
  **ffmpeg completo**, plugins **GStreamer** (good/bad/ugly/libav) e aceleração de vídeo
  por hardware (mesa `va`/`vdpau` freeworld).
- **VLC pré-instalado** (toca praticamente qualquer formato).
- Tudo **embutido no build** (build-time) — **não afeta a imutabilidade em runtime**.

## 3. Drivers de terceiros (garantidos — na instalação e depois)

Há um trade-off real com a imutabilidade. Política adotada:

- **Na instalação:** firmwares e drivers comuns **pré-embutidos** na imagem
  (linux-firmware, Mesa; **variante de imagem com NVIDIA** para quem precisa).
  Cobre a maioria dos casos sem o usuário fazer nada.
- **Depois da instalação:** duas vias suportadas —
  1. **Rebase para uma variante com o driver** (ex.: imagem `-nvidia`) — 100% imutável e atômico.
  2. **Escape hatch documentado:** layering de módulos de kernel (akmods) via `rpm-ostree` —
     atômico e reversível (rollback). É a **exceção controlada** à regra "sem layering",
     reservada a hardware fora do comum.

Assim garantimos "permitir drivers de terceiros" sem abrir mão da imutabilidade do dia a dia.

## 4. Hardware alvo (tiers)

- **Mínimo:** 2 núcleos / **4 GB** — criação leve, escritório, web. Apps pesados (vídeo/3D)
  ficam como **opcionais**, não pré-instalados por padrão.
- **Recomendado:** 4 núcleos / **8 GB+** — pacote completo, incluindo DaVinci Resolve/Blender.
