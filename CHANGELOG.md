# Histórico

## 1.5.0 — interface minimalista

- Números do lote em uma faixa de 28 px, sem cartões e com fonte de 10 pt.
- Cabeçalho compacto, sem navegação duplicada, mais espaço útil para a fila e painéis sem molduras.
- Transições curtas de hover, interruptores e indicador de aba; temporizadores encerrados ao atingir o estado final.
- Correção de repintura completa nos controles desenhados, eliminando restos de bordas e desenhos ao redimensionar.
- Testes com canvas preservado reproduzem falhas na 1.4 e verificam repintura parcial, maximizar/restaurar, resumo compacto e movimento na 1.5. A renderização completa isolada usada antes não detectava essa regressão.

## 1.4.0 — Video Studio

- Nova identidade escura com ciano/violeta, marca vetorial, navegação lateral e botões em degradê.
- Biblioteca com ilustração local e atalho para adicionar pasta; status coloridos e progresso animado apenas enquanto ativo.
- Barra de título escura em versões compatíveis do Windows, foco de teclado visível e painel adaptável com rolagem em janelas pequenas.
- Mantidos início/fim livres, áudio opcional, varredura recursiva e preservação dos originais.
- Teste de interface com renderização das três abas em 1260×720 e 960×560, validação dos tempos e reabertura repetida dos menus.

## 1.3.0 — programa instalável

- Interface e classes de segurança compiladas em um EXE x64; processamento PowerShell embutido como recurso.
- Instalador em português, para o usuário atual, com atalhos e desinstalador.
- Vídeos e resultados separados dos arquivos instalados.
- Verificação de requisitos, de arquivos em uso e de caminhos de instalação.
- Autoteste do executável e testes isolados de instalação e de processamento real de vídeo.
- Organização dos fontes e tutoriais para publicação no GitHub; dependências de vídeo fornecidas separadamente no build.

## 1.2.0 — recorte e organização de pastas

- Recorte com início e fim em segundos, inclusive valores decimais.
- Busca recursiva por vídeos e preservação da estrutura relativa de subpastas na saída.
- Tratamento de colisões de nomes ao converter formatos para MP4.
- Preservação dos originais e substituição de resultados somente quando habilitada.
- Ajustes no painel, edição dos campos de tempo e ciclo de vida dos menus.

Veja os instaladores publicados em [Releases](https://github.com/luziellacerda/APARADOR-LZ/releases) e os detalhes de [distribuição das dependências](docs/DEPENDENCIAS.md).
