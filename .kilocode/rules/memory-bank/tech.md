# Technical Context: Next.js Starter Template

## Technology Stack

| Technology   | Version | Purpose                         |
| ------------ | ------- | ------------------------------- |
| Next.js      | 16.x    | React framework with App Router |
| React        | 19.x    | UI library                      |
| TypeScript   | 5.9.x   | Type-safe JavaScript            |
| Tailwind CSS | 4.x     | Utility-first CSS               |
| Bun          | Latest  | Package manager & runtime       |

## Development Environment

### Prerequisites

- Bun installed (`curl -fsSL https://bun.sh/install | bash`)
- Node.js 20+ (for compatibility)

### Commands

```bash
bun install        # Install dependencies
bun dev            # Start dev server (http://localhost:3000)
bun build          # Production build
bun start          # Start production server
bun lint           # Run ESLint
bun typecheck      # Run TypeScript type checking
```

## Project Configuration

### Next.js Config (`next.config.ts`)

- App Router enabled
- Default settings for flexibility

### TypeScript Config (`tsconfig.json`)

- Strict mode enabled
- Path alias: `@/*` → `src/*`
- Target: ESNext

### Tailwind CSS 4 (`postcss.config.mjs`)

- Uses `@tailwindcss/postcss` plugin
- CSS-first configuration (v4 style)

### ESLint (`eslint.config.mjs`)

- Uses `eslint-config-next`
- Flat config format

## Key Dependencies

### Production Dependencies

```json
{
  "next": "^16.1.3", // Framework
  "react": "^19.2.3", // UI library
  "react-dom": "^19.2.3" // React DOM
}
```

### Dev Dependencies

```json
{
  "typescript": "^5.9.3",
  "@types/node": "^24.10.2",
  "@types/react": "^19.2.7",
  "@types/react-dom": "^19.2.3",
  "@tailwindcss/postcss": "^4.1.17",
  "tailwindcss": "^4.1.17",
  "eslint": "^9.39.1",
  "eslint-config-next": "^16.0.0"
}
```

## File Structure

```
/
├── .gitignore              # Git ignore rules
├── package.json            # Dependencies and scripts
├── bun.lock                # Bun lockfile
├── next.config.ts          # Next.js configuration
├── tsconfig.json           # TypeScript configuration
├── postcss.config.mjs      # PostCSS (Tailwind) config
├── eslint.config.mjs       # ESLint configuration
├── public/                 # Static assets
│   └── .gitkeep
├── src/                    # Source code
│   └── app/                # Next.js App Router
│       ├── layout.tsx      # Root layout
│       ├── page.tsx        # Home page
│       ├── globals.css     # Global styles
│       └── favicon.ico     # Site icon
└── libmem/                 # 32-bit x86 memory library (NASM + GCC -m32)
    ├── mymem.h             # C header (all prototypes)
    ├── memset.asm          # Phase 1: forward byte fill
    ├── memzero.asm         # Phase 2: → memset delegation
    ├── memset_rev.asm      # Phase 3: backward byte fill
    ├── memzero_rev.asm     # Phase 3: → memset_rev delegation
    ├── secure_wipe_stack_rev.asm  # Phase 5: → memset_rev (libmysecure.a)
    ├── Makefile            # nasm -f elf32 + ar rcs
    ├── test_link.c         # C test harness (8 tests)
    ├── libmymem.a          # Build artifact (gitignored)
    └── libmysecure.a       # Build artifact (gitignored)
```

## x86-32 Build Toolchain

| Tool | Version | Purpose |
|------|---------|---------|
| NASM  | 2.15+  | Assemble ELF32 (.o) from .asm sources |
| GCC   | 11.4+  | Compile/link C test harness (-m32, cdecl) |
| GNU ar| 2.38+  | Create static archives (.a) |

Build from `libmem/`:

```bash
make all      # Assemble + archive libmymem.a and libmysecure.a
make test     # Build + run test_link (8 functional tests, zero warnings)
make clean    # Remove all build artifacts
```

## Technical Constraints

### Starting Point

- Minimal structure - expand as needed
- No database by default (use recipe to add)
- No authentication by default (add when needed)

### Browser Support

- Modern browsers (ES2020+)
- No IE11 support

## Performance Considerations

### Image Optimization

- Use Next.js `Image` component for optimization
- Place images in `public/` directory

### Bundle Size

- Tree-shaking enabled by default
- Tailwind CSS purges unused styles

### Core Web Vitals

- Server Components reduce client JavaScript
- Streaming and Suspense for better UX

## Deployment

### Build Output

- Server-rendered pages by default
- Can be configured for static export

### Environment Variables

- None required for base template
- Add as needed for features
- Use `.env.local` for local development
