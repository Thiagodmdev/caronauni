# CaronaUni

Aplicativo de caronas para a comunidade acadêmica, desenvolvido em Flutter como trabalho da faculdade.

## Conteúdo

- `CaronaUni_DRS.docx`: Documento de Requisitos de Software.
- `caronauni_app/`: aplicativo Flutter (Android, iOS e web).

## Como rodar

Requer o [Flutter](https://docs.flutter.dev/get-started/install) 3.47 ou superior.

```bash
cd caronauni_app
flutter pub get
flutter run            # no emulador ou celular conectado
flutter run -d chrome  # no navegador
```

Esta primeira versão usa dados de exemplo. Crie uma conta com um e-mail `@aluno.faculdade.edu.br` (a confirmação é simulada e a conta some ao fechar o app) ou entre com `demo@aluno.faculdade.edu.br` e senha `carona123`.

Telas prontas: login, cadastro, confirmação de e-mail, busca de caronas e detalhes da carona com pedido de vaga.

## Testes

```bash
cd caronauni_app
flutter analyze
flutter test
```

## Equipe

- Esdras Elohim Cardoso Silva
- Eduardo Martins da Silva
- Thiago Victor Dias Macêdo
