---
marp: true
theme: gaia
class: lead, invert
---

# Automatic Secret rotation with ESO
Gergely Brautigam 

https://github.com/Skarlso
https://gergelybrautigam.com 
https://github.com/external-secrets

![width:200px](eso-round-logo.svg) <!-- Setting both lengths -->

---

# Agenda

- External Secrets intro
- Rotation
- ESO Reloader
- Demo
- Caveats
    - Downtime
    - Race conditions
- Closing words

---

# What is External Secrets Operator

<style>
img[alt~="center"] {
  display: block;
  margin: 0 auto;
}
</style>

![width:300px center](secrets.png)

<!-- ![bg](secrets.png) -->

---

# What are generators

![width:500px center](generators_architecture.png)

---

# 