<div align="center">
  <img src="https://janewu77.github.io/whisper_coach/img/logo.jpg" alt="Whisper Coach" width="120" />

# Whisper Coach ⚽

*Whisper your tactics, AI does the rest.* From team photo to lineup, voice notes to live suggestions, and automatic match reports — all hands-free on the touchline.

<a href="https://github.com/DachengChen"><img src="https://github.com/DachengChen.png" width="32" style="border-radius:50%" alt="Dacheng Chen"/></a> &nbsp;
<a href="https://github.com/janewu77"><img src="https://github.com/janewu77.png" width="32" style="border-radius:50%" alt="Jing Wu"/></a> &nbsp;
<a href="https://github.com/qiaoziliang"><img src="https://github.com/qiaoziliang.png" width="32" style="border-radius:50%" alt="Ziliang Qiao"/></a>

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=flat-square&logo=flutter&logoColor=white)](https://flutter.dev)
[![FastAPI](https://img.shields.io/badge/FastAPI-009688?style=flat-square&logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com)
[![PydanticAI](https://img.shields.io/badge/PydanticAI-E92063?style=flat-square)](https://ai.pydantic.dev)
[![OpenAI GPT-4o](https://img.shields.io/badge/OpenAI-GPT--4o-412991?style=flat-square&logo=openai&logoColor=white)](https://openai.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow?style=flat-square)](LICENSE)

Built at the [AI BEAVERS Founder Hackathon](https://luma.com/hmqh70k1) · Hamburg · Jun 6 2026

</div>


## Live

| Service | URL |
|---|---|
| Flutter Web app | [janewu77.github.io/whisper_coach/app/](https://janewu77.github.io/whisper_coach/app/) |
| Project home page | [janewu77.github.io/whisper_coach/](https://janewu77.github.io/whisper_coach/) |
| Backend API | [whisper-coach.dacheng.dev](https://whisper-coach.dacheng.dev) · [/docs](https://whisper-coach.dacheng.dev/docs) |

## Screenshots

<div align="center">

| Create match | AI Lineup | Live suggestions |
|:---:|:---:|:---:|
| <img src="https://janewu77.github.io/whisper_coach/shots/01-new-match.png" width="200"/> | <img src="https://janewu77.github.io/whisper_coach/shots/03-lineup.png" width="200"/> | <img src="https://janewu77.github.io/whisper_coach/shots/06-suggestions.png" width="200"/> |

</div>

## Core flow

```
roster photo → match setup → auto formation/lineup → live adjustments (voice/text) → post-match summary
```

## Architecture

**Backend** (`backend/`) — FastAPI + PydanticAI + PostgreSQL, three AI agents:
1. **Roster extractor** — team photo → structured player list
2. **Lineup generator** — players + opponent → `{formation, lineup, reason}` (e.g. 4-3-3)
3. **Match analyst** — live notes + events → post-match summary

**Frontend** (`frontend/`) — Flutter app, four screens:

| Route | Screen | Purpose |
|---|---|---|
| `/` | Match list | Browse existing matches |
| `/new` | Create match | Upload roster photo, fill opponent info, generate lineup |
| `/pitch` | Pitch | 2D lineup view, formation notes, regenerate |
| `/live` | Live notes | Voice (default) or text → AI suggestions; end match → summary |

## Project layout

```
whisper_coach/
  backend/          FastAPI + PydanticAI + Alembic + Docker
  frontend/         Flutter app + build scripts
  docs/             GitHub Pages (home page + Flutter web build output)
  scripts/          Repo-level helper scripts
```

## Quick start

### Backend

```bash
cd backend
uv venv && uv pip install -e ".[dev]"
cp .env.example .env          # set DB_URL and OPENAI_API_KEY
uv run alembic upgrade head
uv run uvicorn app.main:app --reload
# → http://localhost:8000
```

### Frontend

```bash
cd frontend
flutter pub get
flutter run -d chrome --web-port 3000
# change API base URL in lib/config.dart if using a local backend
```

## Further reading

- [`backend/README.md`](backend/README.md) — local dev, REST API reference, Docker, Coolify deployment
- [`frontend/README.md`](frontend/README.md) — Flutter setup, build & deploy to GitHub Pages

---

## 🏆 Hackathon

<div align="center">

### [founder hackathon: build fast & get funded](https://luma.com/hmqh70k1)

*150 selected founders & builders · one day · zero pre-built code · ship a product & pitch to VCs*

<br/>

[![AI BEAVERS](https://img.shields.io/badge/Host-AI%20BEAVERS-2e9e5b?style=for-the-badge)](https://ai-beavers.com)
[![Mollie](https://img.shields.io/badge/Partner-Mollie-000000?style=for-the-badge)](https://www.mollie.com/)
[![Hamburg](https://img.shields.io/badge/Hamburg-House%20of%20AI-ffb703?style=for-the-badge)](#-hackathon)

</div>

<table>
  <tr>
    <td align="center" width="25%">📅<br/><b>Sat, Jun 6 2026</b><br/><sub>09:00 – 21:00</sub></td>
    <td align="center" width="25%">📍<br/><b>House of AI</b><br/><sub>Hongkongstraße 2, Hamburg</sub></td>
    <td align="center" width="25%">🚀<br/><b>Build from scratch</b><br/><sub>ideas OK · no pre-built repos</sub></td>
    <td align="center" width="25%">🎤<br/><b>Pitch to VCs</b><br/><sub>feedback + early backers on site</sub></td>
  </tr>
</table>

<br/>

**🎁 Sponsors & tools we used**

<div align="center">

[![OpenAI](https://img.shields.io/badge/OpenAI-412991?style=flat-square&logo=openai&logoColor=white)](https://openai.com)
[![Cursor](https://img.shields.io/badge/Cursor-000000?style=flat-square&logo=cursor&logoColor=white)](https://cursor.com)
[![Qwen](https://img.shields.io/badge/Qwen-615EFF?style=flat-square)](https://qwen.ai)
[![ElevenLabs](https://img.shields.io/badge/ElevenLabs-000000?style=flat-square)](https://elevenlabs.io)
[![Bilt](https://img.shields.io/badge/Bilt-0066FF?style=flat-square)](https://bilt.com)
[![SAGEOBOT](https://img.shields.io/badge/SAGEOBOT-2e9e5b?style=flat-square)](#-hackathon)

</div>

> Organized by **Vladyslav Nyzhashchyy** · **Alexander Zakharov** ([AI BEAVERS](https://ai-beavers.com)) — Hamburg's builder & founder community for AI enthusiasts.

---

## 👥 Team

<div align="center">

*Three builders · one pitch day · shipped end-to-end*

</div>

<table>
  <tr>
    <td align="center" width="33%" valign="top">
      <a href="https://github.com/DachengChen"><img src="https://github.com/DachengChen.png" width="100" alt="Dacheng Chen"/></a>
      <h3><a href="https://github.com/DachengChen">Dacheng Chen</a></h3>
      <sub><a href="https://github.com/DachengChen">@DachengChen</a></sub>
      <p>FastAPI · PydanticAI · PostgreSQL<br/>Docker · Coolify · API design · pitch deck</p>
      <p><a href="https://whisper-coach.dacheng.dev">whisper-coach.dacheng.dev</a></p>
    </td>
    <td align="center" width="33%" valign="top">
      <a href="https://github.com/janewu77"><img src="https://github.com/janewu77.png" width="100" alt="Jing Wu"/></a>
      <h3><a href="https://github.com/janewu77">Jing Wu</a></h3>
      <sub><a href="https://github.com/janewu77">@janewu77</a></sub>
      <p>20+ yrs software · ex co-founder<br/>
Flutter · AI/LLM · voice UX · 2D pitch</p>
      <p><sub>Hamburg · Fudan M.Eng · PMP<br/>2× SegmentFault AI Hackathon winner</sub></p>
      <p><a href="https://janewu77.github.io/whisper_coach/app/">Launch the app ↗</a> · <a href="https://linkedin.com/in/janewush">LinkedIn ↗</a></p>
    </td>
    <td align="center" width="33%" valign="top">
      <a href="https://github.com/qiaoziliang"><img src="https://github.com/qiaoziliang.png" width="100" alt="Ziliang Qiao"/></a>
      <h3><a href="https://github.com/qiaoziliang">Ziliang Qiao</a></h3>
      <sub><a href="https://github.com/qiaoziliang">@qiaoziliang</a></sub>
      <p>Test plans · acceptance criteria · pitch deck<br/>Sonar · Radar · LiDAR background</p>
    </td>
  </tr>
</table>

---

## 📬 Get in touch

<div align="center">

Interested in **Whisper Coach** — feedback, collaboration, pilots with your club, or just saying hi?

<br/>

[![GitHub Issues](https://img.shields.io/badge/Open_an_Issue-181717?style=for-the-badge&logo=github&logoColor=white)](https://github.com/janewu77/whisper_coach/issues/new)
[![Launch App](https://img.shields.io/badge/Try_the_App-2e9e5b?style=for-the-badge&logo=googlechrome&logoColor=white)](https://janewu77.github.io/whisper_coach/app/)
[![API Docs](https://img.shields.io/badge/API_Docs-009688?style=for-the-badge&logo=fastapi&logoColor=white)](https://whisper-coach.dacheng.dev/docs)
[![Pitch Deck](https://img.shields.io/badge/Pitch_Deck-ffb703?style=for-the-badge&logo=googleslides&logoColor=white)](https://janewu77.github.io/whisper_coach/AI_Football_Coach_Pitch_Deck.pdf)

<br/>

*Bug reports & feature ideas → [GitHub Issues](https://github.com/janewu77/whisper_coach/issues)*

</div>