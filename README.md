# hacked.nvim

A collection of smaller plugins / modifications I use for neovim.

> [!caution]
> plugin still in a "draft" state.

## Install

#### [Lazy](https://github.com/folke/lazy.nvim)

```lua
    {
        "josiahdenton/hacked.nvim",
        config = function()
            require("hacked.diagnostics").setup()
            require("hacked.blame").setup()
            require("hacked.executor").setup()
            -- etc.
        end,
    },
```

### Available Plugins

#### blame

- Open a blame window / virtual text for current line / selection.
- Also can browse the commit if you have `gh` installed.

<img width="1505" alt="Screenshot 2025-01-25 at 5 06 39 PM" src="https://github.com/user-attachments/assets/c5b16c2c-c8d7-4072-83a5-9d10dfeac8e2" />

#### diagnostics

- underline diagnostics for errors only

<img width="1512" alt="image" src="https://github.com/user-attachments/assets/00047c51-1abe-41ae-b12b-0ea73c8a0dff" />

#### executor

- execute code blocks in markdown files by hitting `<enter>`. Supports python, go, and javascript.

https://github.com/user-attachments/assets/46ed91b1-58b3-4d06-b5aa-b89885cfdb1b

## Next Steps

- [ ] tree sitter node quick move / swap
- [ ] portal -- used in other modules, can grow as user adds newlines
- [ ] process dump, go through and delete what you want
- [ ] docker dump, start/restart/delete
- [ ] multi-buffer
    - new tab
    - each line has virtual text with error + vt of code block + surrounding
    - uses a borderless portal to edit code block on `<enter>`
    - newlines extend the portal + vt 
    - `<esc><esc>` from insert goes -->normal-->close portal, leaving text behind as vt
    - tab moves next
    - once error is resolved we either leave the diagnostic but gray out OR we re-draw / refresh all diagnostics

