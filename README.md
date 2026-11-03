# NovelVerse — Owner-only novel publishing platform

A React + Vite + Supabase website featuring a public library, optional reader accounts, secure admin-only publishing, chapters, comments, bookmarks, DOCX import, basic page-load statistics, and a CSS page-turn reader.

## 1. Requirements
- Node.js 20.19+ or 22+
- A Supabase project (free tier is suitable for a small prototype)
- Optional: GitHub and Vercel/Netlify for deployment

## 2. Local setup
```bash
npm install
cp .env.example .env
```
Edit `.env` with your **Supabase project URL** and **publishable/anon key** from Supabase > Project Settings > API. Never use the `service_role` key in the frontend.

## 3. Supabase database and storage
1. Create a new Supabase project.
2. Open **SQL Editor** and run the entire `supabase/schema.sql` file once. If rerunning after a partial setup, review existing policies first; `create policy` is not idempotent.
3. In **Authentication > Providers**, enable Email. Decide whether email confirmation is required. In **Authentication > URL Configuration**, set your Site URL and redirect URLs for local development and your deployed site.
4. In **Authentication > Users**, create your personal admin account (or sign up from the website and confirm the email).
5. Copy your admin user's **UUID** from Authentication > Users. In SQL Editor run (replace placeholder with the UUID):
```sql
insert into public.admins(user_id) values ('YOUR-ADMIN-USER-UUID');
```
6. Do not grant other users membership in `public.admins`. No client-side policy allows users to add themselves as admins.
7. The SQL file creates the public `covers` Storage bucket with admin-only write policies. Published cover images are public.

## 4. Run
```bash
npm run dev
```
Visit the local URL printed by Vite (normally http://localhost:5173). Without `.env`, the site runs a read-only demonstration library with sample content. Publishing and accounts require Supabase.

## 5. Publishing
Sign in using your admin credentials. Open **Dashboard** in the navigation. Create a book, add a cover, choose whether to publish it, then select **Chapters** to add/edit chapters. Draft books and chapters are not visible to the public. A chapter is public only when both the chapter and its parent book are published.

For Word imports, open the chapter editor and select a `.docx` file. The text is extracted in the browser using Mammoth; check paragraph breaks before saving. This prototype does not import PDF, EPUB, embedded images, or multiple DOCX chapters at once.

## 6. Deploy to Vercel
1. Push the project to a private or public GitHub repository. **Never commit `.env`**.
2. Import the repository into Vercel.
3. Framework preset: **Vite**. Build command: `npm run build`; output directory: `dist`.
4. Add environment variables `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` in Vercel project settings.
5. Add a rewrite rule for client-side routes. The included `vercel.json` handles this.
6. Deploy. Set the Supabase Authentication Site URL to your production domain and include the domain in Redirect URLs.

## 7. Deploy to Netlify
1. Connect the repository to Netlify.
2. Build command `npm run build`, publish directory `dist`.
3. Set both Vite environment variables in Netlify site configuration.
4. The included `public/_redirects` supports direct links to chapters.
5. Deploy and update Supabase Authentication URL settings.

## Security notes and production limitations
- **Database RLS is the authorization boundary.** Hiding the dashboard is only UX. Admin access is determined by the `admins` table and enforced on book/chapter writes and cover uploads.
- Readers can register and comment/bookmark but cannot publish. Anonymous visitors can read published content.
- Do not expose `service_role` or other secret keys in browser code, Git, or screenshots.
- Comment creation requires a signed-in account. Add spam prevention, moderation tools, rate limiting and abuse reporting before opening public registration widely.
- The view counter counts page loads, not unique people, and can be artificially inflated. Consider server-side rate limits and analytics before relying on it.
- The CSS flip reader divides paragraphs into roughly 850-character pages, rather than precise page measurement. It simulates a page turn, not a full 3D book engine; large paragraphs may overflow and scroll.
- Reader bookmarks automatically update to the current chapter when signed in. Visitors without accounts do not get persistent reading progress.
- The admin can delete comments using the reader interface; the prototype does not include a centralized comment moderation queue.
- No scheduled publishing, notifications, payments, password recovery UI, or email newsletters are implemented.
- For production, configure SMTP, email verification, backups, monitoring, and a custom domain as appropriate.

## Project layout
```
index.html                 Vite entry
src/main.jsx               App, routes, public pages, reader, admin dashboard
src/style.css              Royal blue/violet responsive theme
supabase/schema.sql        Database, RLS, storage, view-counter RPC
.env.example               Public client configuration template
vercel.json                SPA routing for Vercel
public/_redirects          SPA routing for Netlify
```
