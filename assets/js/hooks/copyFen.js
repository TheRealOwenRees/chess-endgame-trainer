export const CopyFen = {
    mounted() {
        this.el.addEventListener("click", e => {
            e.preventDefault()
            const fen = this.el.dataset.fen

            navigator.clipboard.writeText(fen).then(() => {
                const originalHTML = this.el.innerHTML
                this.el.innerHTML = `<svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4 text-emerald-600 inline" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" /></svg> Copied!`

                setTimeout(() => {
                 this.el.innerHTML = originalHTML   
                }, 2000)
            }).catch(err => {
                console.log('Failed to copy FEN: ', err)
            })
        })
    }    
}