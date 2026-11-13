# Handing James part of a task: do the rest, then drop him at his step

When a task needs James for a step you can't or mustn't do, do every other step first, and set up his step so he only has to do the part that needs him. Don't describe where to go, and don't leave a gap he has to come back and ask about.

- **Open everything he needs.** Open the file in VS Code (`code <path>`, never TextEdit) and open the web page in the browser, on the exact page and section, not the site's home page. Create the file first, with its permissions (chmod 600 for a secret) and any surrounding content.
- **Say exactly what's left for him**: "copy the token from the Chrome tab I've opened, paste it into the file open in VS Code, save". Not "go to the API tokens page and create a file with the token".
- **Secrets especially.** You mustn't see a secret, so the copy is his. Everything around it is yours: the file, the page, the command that uses the file afterwards, ready to run.
- **Don't ask on another turn for something you could have looked up**: an ID, a URL, a path, a command. Find it and put it in the hand-off.
- **Then carry on** with whatever doesn't depend on his step, and pick up straight after it when he says it's done.

**Why:** On 2026-11-13 a session told James to "paste the token into `tmp/wallet-tokens/<merchant>.token`", leaving him to find the CRM page, create the file and work out the rest. Every gap costs him a context switch and often a round trip.
