# hacked.nvim

A collection of "plugins" / modifications I use for my own editor.
Use them if you want, many of them are focused on my own experience.

## Next Steps

- [ ] tree sitter node quick move / swap
- [ ] portal -- used in other modules, can grow as user adds newlines
- [x] inline diagnostics
- [ ] using column too so we can get a "helix" experience
- [x] git blame popup
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
- [ ] mv custom tab bar into here as well


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
            -- etc.
        end,
    },
```
