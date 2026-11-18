# Apta AI Skills

The shared language behind the Apta team's agent skills: the standards and workflows an agent follows inside an Apta project.

## Language

### Investigation

**Investigation**:
Finding the cause of a reported issue in a project by checking its code against what its database and logs show.
_Avoid_: Diagnosis, debugging session, troubleshooting

**Environment**:
A named deployment of a project that an Investigation can inspect, such as `dev`, `prod-medan` or `prod-riau`, with exactly one database and its own logs; one stage like prod can have several.
_Avoid_: Stage, profile, target, site

**Environment Settings**:
The non-secret details of how to reach an Environment's database and logs, which the agent may read and edit; either part may be left out.
_Avoid_: Config, env file

**Environment Secrets**:
The passwords and tokens of an Environment, which the agent never sees; only the skill's own tools read them.
_Avoid_: Credentials file, env file, .env

**Evidence Source**:
One of the three places an Investigation draws evidence from: the code, an Environment's database, or its logs.
_Avoid_: Resource, data source

**Corroborated**:
Said of a root cause that the code and at least one other Evidence Source both support; a cause backed by the code alone is _Unconfirmed: code only_.
_Avoid_: Confirmed, verified

**Investigation Report**:
The saved, written record of one Investigation: the symptom, the evidence gathered, the hypotheses ruled out and the conclusion.
_Avoid_: Notes, log, postmortem
