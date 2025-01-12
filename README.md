# hacked.nvim

Lots of optional changes for the editing experience.

## Next Steps

- [ ] tree sitter node quick move / swap
- [ ] ext mark eol tasks, hover to popup, allow inline typing via hidden buffer
- [ ] portal -- used in other modules, can grow as user adds newlines
- [x] float -- open floats easily and everywhere
- [ ] inline diagnostics, using column too so we can get a "helix" experience
- [ ] git blame popup
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
- [ ] hidden cursor input --> use for virtual text editing (would need to figure out how to "draw" my cursor :oof:)
- [ ] can bring in the "tabby" stuff too...


> [!caution]
> plugin still in a "draft" state.

## Install

#### [Lazy](https://github.com/folke/lazy.nvim)

```lua
    {
        "josiahdenton/hacked.nvim",
        config = function()
            require("hacked").setup()
        end,
    },
```
