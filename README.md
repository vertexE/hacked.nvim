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

### Available

#### blame

- Open a blame window / virtual text for current line / selection.
- Also can browse the commit if you have `gh` installed.

#### diagnostics

- underline diagnostics for errors only

#### executor

- execute code blocks in markdown files. Supports python, go, and javascript.

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

