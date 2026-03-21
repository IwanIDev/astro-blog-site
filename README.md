# Astro Blog Site
This is my blog site written with Astro, Tailwind CSS, and shadcn/ui.

## Openring integration

This project integrates [`openring`](https://git.sr.ht/~sircmpwn/openring) to render a webring section on the homepage.

### How it works

- Feed sources are defined in `openring/feeds.txt`.
- The template is defined in `openring/template.html`.
- Generated output is written to `openring/out.html`.
- `bun run dev` and `bun run build` both run `bun run openring:generate` first.

### Install openring

Install the `openring` binary (example using Go):

```bash
go install git.sr.ht/~sircmpwn/openring@latest
```

Make sure your Go bin directory is in `PATH`, then generate output:

```bash
bun run openring:generate
```

If `openring` is not installed (or feed fetch fails), the generator writes a small fallback section so builds still succeed.
