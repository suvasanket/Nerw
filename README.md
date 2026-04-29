# Nerw 🌸
The **Smartest, Fast, Native, Powerful** universal search for macOS

## Smartest
- **Typo Resistant:** Nerw uses levenstain's algorithm in-order to achieve the best result even with typo in the user query.
- **Natural Language Categorizer:** It uses Natural Language Processor to categorize the query based on user intent(Used in websearch filteration and will be use for ai prompt guess in future).
- **Frecency:** Frequently and Recently, based on user usage pattern ranks the results accordingly.
- **Smart Query Cacher:** Map queries to specific action(user selected) and cache it.(eg. Lets say you have a query you want to pass into a action and the top action is not the intended one so you choose the required now it will be mapped and stored such that in future it will take priority)

## Why "Powerful"?
There are already a lot of spotlight replacements and They have **Extensions** which gives them the actual superpower.


Nerw also have Extension support, then what makes it different?
- Instead of using any web frameworks or shell scripts etc, Nerw provides the functionality to create Extensions using **Swift(the language used to create apps and stuff)**.
- Which means you can literally create a native app and package it into a extension and then share, use or do whatever you want with it.
- And as you are using a system language that means you can tap into the system apis to achieve anything(Although dangerous but still the potential is there for you).

## Build
iykyk(hint: makefile)

## Acknowledement
- [Ifrit](https://github.com/ukushu/Ifrit)
