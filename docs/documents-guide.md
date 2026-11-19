[Español](guia-documentos.md) · **English**

# Guide: getting the terminal to answer from your business's documents

This guide is for people who run a business and want to ask the `AI`
terminal things like "what time does the Riverside location open on
Sunday?" or "how many vacation days do I get?" and get an answer based on
what **their own documents** say. You don't need to know anything about
computers. The technical details are in the ["Documents" section of the
README](../README.md#documents).

The examples in this guide are real output from the program, using Gemma 4
E4B (the local model) and a made-up coffee shop, Linden Street Coffee House,
the same one the tests use (the whole conversation is in
[`docs/video/capturas/en`](video/capturas/en/3-preferences-documents.out)).
Where it says `User >`, your screen will show your Windows user name.

The commands in this guide are the English ones. The Spanish names work
too (`/documentos buscar` is the same as `/documents search`), and the
program understands requests in either language ("learn from the documents
in..." or "aprende de los documentos de..."). To switch the program's
language, type `/language en` or `/language es`.

If you'd rather watch before you read, the [English
video](https://www.youtube.com/watch?v=7vM_9QslKjo) shows this same
coffee shop: learning from the folder, asking questions, checking where a
fact comes from, and forgetting (from minute 1:02).

## What it does and what it doesn't

- **It reads your documents and answers with what they say,** and it tells
  you which document each fact comes from.
- **If something isn't in your documents, it tells you so** instead of
  making it up.
- **It doesn't change your files,** delete them, or move them.
- **Everything stays on your computer.** With the local model (the one it
  comes with) nothing goes out to the internet.
- **It doesn't "learn" the way a person does.** For each question it looks
  up the pieces of your documents that matter and shows them to the model
  along with the question. That's why, if you change a document, the next
  answer already uses the new version.

## 1. Get the folder ready

1. **Make a folder for the business,** for example `D:\MyBusiness`. You can
   make subfolders inside it (`Human resources`, `Procedures`...): they all
   get read.
2. **Put in it whatever you want it to know:** who you are, products and
   prices, opening hours, employees and their shifts, vacation and leave,
   employee handbook, procedures (opening, closing, complaints, orders),
   suppliers, inventory, goals...
3. **Leave out what you don't want it to answer.** If a document has pay
   rates or personal information and you don't want them showing up in an
   answer, keep that document out of the folder, or ask it to forget them
   later (see section 6).
4. **A few tips that make the answers much better:**
   - **Clear names:** `Menu and prices.xlsx` is better than `doc1.xlsx`. The
     document's name shows up in every answer.
   - **Headings in Word:** use the "Heading 1", "Heading 2"... styles. Each
     heading is a section, and later you can check or forget a section by
     its name.
   - **Tables with a header row:** in Excel, put the column names in the
     first row (`Item`, `Price`, `Effective since`). That way each fact
     comes with its label ("Price: $8.00").
   - **Only one version of each thing.** If two documents have two
     different schedules, the model will see both and may mix them up.
     Delete the old one or take it out of the folder.
   - **Write things the way you'd ask about them.** It searches by words:
     if the document says "uniform" and you ask about "work clothes", it may
     not find it.
5. **Limits:** up to 10 folders, 3,000 files across all of them, and 30 MB
   per file. That's plenty for a small or medium business.

## 2. Which formats work

| It reads | Examples |
| --- | --- |
| Word | `.docx` (with its headings, lists, and tables) |
| Excel | `.xlsx` (every sheet; dates and times come out as dates and times) |
| PowerPoint | `.pptx` (each slide, in order) |
| PDF | `.pdf` with text (with its headings and tables; not scanned ones: see below) |
| LibreOffice / OpenOffice | `.odt`, `.ods`, `.odp` |
| Text | `.txt`, `.md`, `.csv`, `.html`, `.rtf`, and other text files |

Pictures (photos, logos) and any other files are simply skipped. So are
Word's temporary files (the ones that start with `~$`) and hidden files.

### PDFs

**It reads PDFs that have text in them:** the ones made from Word or Excel
with "Save as PDF", the ones from a PDF printer (like "Microsoft Print to
PDF"), and the ones saved from a web browser. Just like with a Word file, it
picks out the headings (it recognizes them by the size of the letters) and
the tables, row by row.

A quick way to tell whether a PDF has text: open it and try to select a word
with the mouse. If you can, it can read it.

Some PDFs it can't read. When it reads the folder it tells you which ones
and why:

- **Scanned documents or photos** ("it has no text"): they're a picture of
  the page. They have to be typed up by hand or run through a text
  recognition program (OCR). If the scan already has OCR done (you can
  select the text), it does read it.
- **Protected** with a password or against copying: open it and, if it lets
  you, print it to "Microsoft Print to PDF" to get a copy without the
  protection.
- **With fonts that can't be decoded:** some PDFs draw the letters without
  saying which letters they are. Reading them would give scrambled letters,
  and scrambled letters in a price or a phone number would be false
  information. So instead of reading them wrong, it tells you it couldn't
  read them.

**If you have the original** (the Word or Excel file the PDF came from), put
the original in instead: it brings its headings and table headers exactly as
they are, while a PDF has to be pieced back together from where each letter
sits on the page.

### Old Office formats

They aren't read: open them and use "Save as" with the new format (`.doc` →
`.docx`, `.xls` → `.xlsx`, `.ppt` → `.pptx`).

## 3. Show it the folder

Open the terminal, type `AI`, and ask in your own words, with the folder's
location:

```
User > learn from the documents in D:\MyBusiness
ai > I'm going to read the documents in D:\MyBusiness to answer you with what they say. I don't
     change them or send them anywhere: what I read stays on this computer.
ai > There are 14 I can read (3 Word, 2 OpenDocument, 2 text, 2 PDF, 1 RTF, 1 HTML, 1 Excel,
     1 CSV, 1 PowerPoint).
ai > What are they about, in a few words? That way I know when to look at them; for example "my
     hardware store: services, staff, opening hours and procedures". (Enter: "MyBusiness";
     "cancel" to leave it)
User > my coffee shop: menu, prices, staff, hours and procedures
ai > Done: I read 13 documents (30 passages) in 1.8 s. Ask me anything about my coffee shop:
     menu, prices, staff, hours and procedures and I'll tell you which document each fact
     comes from. If you change or add files in the folder, I read them again on my own.
ai > I could not read these:
  Invoices\Flour invoice November.pdf: it has no text (is it a scanned image?)
```

- **It asks what the documents are about.** Answer in a few words: that's
  what tells it when to look at them. If you just press Enter, it uses the
  folder's name; "cancel" drops it.
- **It tells you what it couldn't read** and why: here, a scanned invoice,
  which is a photo and has no text. The cakes and pastries catalog, which is
  also a PDF, it did read.
- **You only need to do this once.** The next times you open `AI` it
  already has them. If you change, add, or delete files in the folder, it
  notices on its own (it checks every five minutes). If you're in a hurry:
  `/documents update`.
- **If the location has spaces,** that works too: `learn from the documents
  in D:\My documents\My business`. If it can't find it, put it in quotes.

To see at any time which folders it has and how much it read, type
`/documents`.

## 4. How to ask

Ask the way you'd ask an employee who has the documents right in front of
them:

```
User > What time does the Riverside location open on Sundays?
ai > checking your documents: Menu and prices.xlsx, Procedures\Opening and closing.docx, About
     us.docx
ai > The Riverside location opens at 8:00 AM on Sundays. This information comes from Menu and
     prices.xlsx.
   documents: Menu and prices.xlsx  Procedures\Opening and closing.docx  About us.docx
User > How much is a whole carrot cake?
ai > checking your documents: Cakes and pastries catalog.pdf, Menu and prices.xlsx
ai > A whole carrot cake is $48.00. This comes from Cakes and pastries catalog.pdf.
   documents: Cakes and pastries catalog.pdf  Menu and prices.xlsx
User > How much does Megan Reyes make?
ai > checking your documents: Procedures\Opening and closing.docx, Cakes and pastries catalog.pdf,
     Employees.csv
ai > Megan Reyes' hourly pay is not stated in the documents. Her role is Cashier in the Downtown
     location. This comes from Employees.csv.
   documents: Procedures\Opening and closing.docx  Cakes and pastries catalog.pdf  Employees.csv
```

The answers are short because earlier in that conversation it had been told
"remember to always answer me in short sentences" (see
["Preferences" in the README](../README.md#preferences)).

- **Before answering, it says which documents it's checking,** and in the
  answer, which one the fact comes from. To see the exact section of the
  document (for example the "Prices" section of the PDF), use
  `/documents search` (section 5).
- **If it isn't there, it says so.** Look at the pay question above: Megan
  Reyes' pay isn't in the documents, and instead of making up a number it
  says so, and tells you what it does know. That's what's supposed to
  happen.
- **One thing per question** works better than three at once.
- **Use the words from your documents:** "Riverside location", "starting
  cash", "event orders". If something has its own name in your business,
  use it.
- **You can keep the conversation going:** after "what time does Downtown
  open on weekdays?", "and on Saturdays?" works.
- **Everything else it answers as usual.** "What's the capital of France?"
  or "write me a message to congratulate a customer" don't touch your
  documents.

## 5. Check where a fact comes from

If an answer seems off, look at which pieces of your documents the model
would see with that question. This doesn't ask the model: it's a direct
search, and it's instant.

```
User > /documents search carrot cake
  1. Cakes and pastries catalog.pdf > Cakes and pastries catalog > Prices  (4.76 points)
     Cake | Slice | Whole (12 slices)
     Carrot cake | $5.50 | $48.00
     Chocolate hazelnut | $6.25 | $58.00
     Lemon blueberry | $5.75 | $52.00
     Black Forest | $6.50 | $62.00
  2. Menu and prices.xlsx > Sheet: Bakery  (2.71 points)
     Item: Sourdough loaf | Price: $8.00 | Unit: loaf | Effective since: 10/15/2026
     Item: Baguette | Price: $4.25 | Unit: each | Effective since: 10/15/2026
     Item: Croissant | Price: $3.75 | Unit: each | Effective since: 10/15/2026
     Item: Blueberry muffin | Price: $3.25 | Unit: each | Effective since: 10/15/2026
     Item: Carrot cake | Price: $5.50 | Unit: slice | Effective since: 10/15/2026
  3. Cakes and pastries catalog.pdf > Cakes and pastries catalog  (2.36 points)
     All our cakes are baked at the Downtown location with fresh ingredients.
     Whole cakes must be ordered 3 days in advance.
  4. Cakes and pastries catalog.pdf > Cakes and pastries catalog > Decorations  (2.15 points)
     A name or message on the cake is free.
     An edible photo costs $12.00 extra.
     Fondant figures are quoted separately, depending on the design.
(the model would get these with that question on its own; coverage 1)
```

- **Each result shows the document and the section** (`Cakes and pastries
  catalog.pdf > ... > Prices`) and the text exactly as it was read. In a
  PDF, the columns of a table are separated by ` | `. In the Excel file,
  each value comes with its column name (`Price: $8.00`) because the sheet
  has a header row.
- **Here you can see why it pays to keep only one version of each thing:**
  the price of a slice is in both the PDF and the Excel file. They match
  ($5.50), so there's no problem; if they didn't, the model would see both.
- **The points** say how well each piece matches what you searched for: the
  first one matches best.
- **The last line says whether those pieces would reach the model on their
  own** with that question. If it says they wouldn't, try asking in other
  words, the ones the document uses.
- **If the fact is wrong in the piece, it's wrong in the document:** fix it
  in the file and the next answer will already use the new version.

## 6. Forgetting, and undoing it

You can ask it to stop using something. **Your files are not touched:**
what gets forgotten is what it read from them.

```
User > forget about the extension
ai > I'm going to forget what mentions "extension" (6 lines of Employees.csv). Your files are not touched.
  for example:
  - Employees.csv: Extension: 101
  - Employees.csv: Extension: 102
  - Employees.csv: Extension: 103
  - Employees.csv: Extension: 200
  - Employees.csv: Extension: 201
    and 1 more
ai > Shall I forget it? ("yes" or "no")
User > yes
ai > Forgotten. If you change your mind: /documents forgotten and /documents restore <number>.
ai > What I already told you in this conversation is still in its memory; /new clears it.
User > /new
memory cleared
User > What is Anna Walsh's extension?
ai > checking your documents: Procedures\Opening and closing.docx, Employees.csv
ai > The provided documents do not state Anna Walsh's extension.
   documents: Procedures\Opening and closing.docx  Employees.csv
User > /documents forgotten
  1. what mentions "extension"  (2026-11-19)
(/documents restore <number> undoes one)
User > /documents restore 1
using again: what mentions "extension"
```

After forgetting the extension, it no longer gives it out. The rest of Anna
Walsh's row (her name, role, location, and shift) is still there: only the
extension was removed.

What you can forget and how to ask:

| What | How to ask |
| --- | --- |
| A topic, across all the documents | "forget about the hourly pay" |
| A whole document | "forget the document Employees.csv" |
| A section of a document | "forget the section Leave" |
| A folder | "stop using the folder MyBusiness" |
| Everything | "forget everything you learned" |

- **It always shows you what it's going to forget,** with examples, and
  waits for your "yes". With "no" it doesn't forget anything.
- **A topic is removed carefully:** only the lines that talk about it. In a
  table of employees, "forget about the extension" removes each person's
  extension and keeps their name, role, and shift.
- **Whatever it already told you in the conversation is still in that
  conversation's memory.** Type `/new` to start a new one, or close `AI`
  and open it again.
- **To undo it:** `/documents forgotten` lists what was forgotten, with a
  number, and `/documents restore <number>` starts using it again.
- **Forgetting a folder or everything can't be undone that way:** the
  folder comes off the list. To use it again, ask it to learn from it again.
- You can also type it as a command: `/documents forget <document, section,
  topic, or everything>`.

## 7. Privacy

- **Your documents are never changed.**
- **What it reads is saved on your computer,** in
  `%LOCALAPPDATA%\PRC-CMD-AI\documentos\`, so it doesn't have to reread it
  every time. If you forget everything, that copy is deleted.
- **They're only used with the local model** (Gemma, the one it comes with,
  or Qwen or Ollama), which runs on your own computer. If you switch to an
  internet model (OpenAI or Grok), the pieces of your documents would leave
  your computer, so **they are not sent** and it warns you.
- **If you really do want to use them with an internet model,** type
  `/documents cloud on`. It only lasts for that session; `/documents cloud
  off` turns it off. Think it over first: whatever is in those pieces
  (prices, employees, procedures) will reach that company.
- **To turn them off for a while:** `/documents off` (and `/documents on` to
  turn them back on).

## 8. Frequently asked questions

**Do I have to show it the folder again every day?**
No. It remembers the folders from one time to the next, and it notices
changes on its own.

**I changed a price in the Excel file and it still gives me the old one.**
It checks the folders every five minutes. Type `/documents update` to make
it check right away. If it's still the same, use `/documents search` to see
what it's reading: there may be another document with the old price.

**It told me something that isn't right.**
Use `/documents search` with the words from your question: you'll see which
pieces it got. If the fact is right in the piece, the model read it wrong:
ask in a more specific way. If it's wrong in the piece, fix the document. If
two documents say different things, keep only one.

**It says it's not in the documents, but it is.**
That's usually because the question uses different words. Try
`/documents search` with the document's words, and ask using them.

**Can I put in a PDF?**
Yes, if it has text (if you can select a word with the mouse). Scanned
ones, protected ones, and some with unusual fonts can't be read, and it
tells you which ones: see section 2.

**Can anyone outside see my documents?**
With the local model, no: everything happens on your computer. They would
only leave it if you turn on `/documents cloud on` with an internet model.

**What if I delete a document from the folder?**
It notices at the next check and stops using it.

**How many documents can it read?**
Up to 3,000 files. About 400 documents are read the first time in around 5
seconds, and after that each question searches in a fraction of a second.
PDFs take longer: a long PDF takes a few seconds the first time (after that
it isn't reread unless it changes).

**Can I use it on another computer?**
Yes, if that computer has `AI` installed and the folder. Each computer reads
the folder on its own.

## Cheat sheet

| To | Type |
| --- | --- |
| Read a folder | `learn from the documents in D:\MyBusiness` |
| See which folders it has | `/documents` |
| See where an answer would come from | `/documents search <words>` |
| Reread changes right away | `/documents update` |
| Forget something | `forget about <topic>` |
| See what was forgotten | `/documents forgotten` |
| Undo a forget | `/documents restore <number>` |
| Stop reading a folder | `/documents remove <name>` |
| Turn the documents off or on | `/documents off` / `/documents on` |
| Switch the language | `/language en` / `/language es` |
| Start a new conversation | `/new` |
