# Orbit Bounce (Pong Circular) 🪐⚪

MVP de um jogo mobile 2D de ritmo rápido no estilo "Pong Circular" desenvolvido em **Godot 4.x** com **GDScript 2.0**.

Desenvolvido com arquitetura vetorial matemática pura e renderização gráfica procedural via `CanvasItem._draw()`, sem necessidade de texturas ou assets externos.

---

## 🎮 Mecânicas do Jogo

- **Orientação Mobile Portrait:** Resolução base 720x1280.
- **Arena Circular:** A partida acontece no interior de uma arena circular limpa.
- **Raquete Deslizante:** O jogador controla um arco que desliza suavemente pela borda da arena via touch drag, mouse ou setas do teclado.
- **Física Vetorial da Bolinha:** A bola rebate na raquete, acelerando 2% a cada rebatida bem-sucedida (+1 ponto). Se passar pela borda sem tocar a raquete, ocorre Game Over.
- **Alvos Centrais:** Surgem periodicamente próximos ao centro. Ao serem atingidos, concedem pontuação extra (+5 pontos) e moedas virtuais (+1 moeda).
- **Interface e HUD:** Pontuação em tempo real, contador de moedas e painel de Game Over com botão de reinício instantâneo.

---

## 🚀 Como Executar

### Pré-requisitos
- [Godot Engine 4.x](https://godotengine.org) instalado.

### Executando Localmente
1. Clone este repositório:
   ```bash
   git clone https://github.com/marcos-toliveira/orbit-bounce.git
   cd orbit-bounce
   ```
2. Abra no Godot:
   - Abra o Godot Editor e importe a pasta do projeto, **ou** execute diretamente via terminal:
   ```bash
   godot --path .
   ```

---

## 📜 Licença e Termos de Uso

Este projeto adota a licença **[PolyForm Noncommercial License 1.0.0](LICENSE)** (Source-Available / Código Aberto para Uso Não Comercial).

### ✅ O que você PODE fazer:
- Baixar, clonar e inspecionar o código-fonte livremente.
- Compilar e jogar na sua máquina ou dispositivo pessoal para entretenimento próprio e estudos.
- Modificar o código para fins pessoais e educacionais.

### ❌ O que você NÃO PODE fazer:
- Vender, alugar, sublicenciar ou comercializar o código ou seus binários.
- Publicar ou distribuir o jogo (ou derivados) em lojas comerciais de aplicativos (Google Play, Apple App Store, Steam, etc.).
- Monetizar o jogo (anúncios, compras no app ou distribuição paga).

> **Direitos Comerciais:** Todos os direitos de exploração comercial, publicação em lojas e monetização são reservados exclusivamente a **Marcos T. Oliveira** (`marcos-toliveira`).
