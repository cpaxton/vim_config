set nocompatible              " be iMproved, required
filetype off                  " required

set autoread                                                                                                                                                                                    
au CursorHold * checktime  

" set the runtime path to include Vundle and initialize
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()
" " alternatively, pass a path where Vundle should install plugins
" "call vundle#begin('~/some/path/here')

" " let Vundle manage Vundle, required
Plugin 'VundleVim/Vundle.vim'
" " Plugin 'ycm-core/YouCompleteMe'

call vundle#end()            " required
filetype plugin indent on    " required

colo molokai
syntax on
let g:molokai_original = 1
" set autoread
set autoread | au CursorHold * checktime | call feedkeys("lh")

set mouse=a
map <ScrollWheelUp> <C-Y>
map <ScrollWheelDown> <C-E>
