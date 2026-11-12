# Complete Guide: Deploying EscrowAPI to Dokploy via GitHub

This guide walks you step-by-step through deploying your .NET API (`EscrowAPI`) to your **Dokploy** server with automated **GitHub** push-to-deploy.

---

## 1. High-Level Architecture

Here is how Dokploy, Traefik, GitHub, and your .NET container interact:

```
[ Developer ]
      │  git push origin main
      ▼
[ GitHub Repository ]
      │  Webhook notification
      ▼
[ Dokploy Server (Your VPS) ]
      │
      ├─► Clones latest commit from GitHub
      ├─► Builds Docker image using multi-stage Dockerfile
      ├─► Spawns Container (Internal Port: 8080)
      │
[ Traefik Reverse Proxy (Built into Dokploy) ]
      │
      ├─► Terminates HTTPS/SSL (Let's Encrypt)
      ├─► Routes https://api.yourdomain.com ──► http://container:8080
      ▼
[ Public Internet / Clients ]
```

---

## 2. Important .NET Core Production Concepts

Before deploying, keep these three .NET container concepts in mind:

| Concept | Local Development | Dokploy / Docker Production | Why? |
| :--- | :--- | :--- | :--- |
| **Port** | `5285` (HTTP) / `7148` (HTTPS) | **`8080`** | Modern .NET runtime containers run as a non-root user (`app`, UID 1654) and listen on internal port `8080` by default. |
| **SSL / HTTPS** | Handled by local dev certificate | Handled by **Traefik** | Dokploy's Traefik proxy handles SSL certificates (Let's Encrypt). The traffic from Traefik to your container is plain HTTP on port `8080`. |
| **OpenAPI / Scalar** | Enabled by default | Disabled by default in `Production` | In `Program.cs`, `app.MapOpenApi()` is wrapped inside `if (app.Environment.IsDevelopment())`. |

---

## 3. Step-by-Step Deployment Instructions

### Step 1: Prepare Git and Repository Files

The root of this project now contains the three files needed for Docker and Git:
1. `Dockerfile` (Multi-stage build optimized for .NET 10).
2. `.dockerignore` (Excludes `bin`, `obj`, `.git`, etc., to keep Docker builds fast and clean).
3. `.gitignore` (Prevents pushing local compilation artifacts to GitHub).

#### Initialize Git & Push to GitHub
Open your terminal in `C:\Users\tyeko\Documents\EscrowAPI` (or your project directory) and run:

```bash
# 1. Initialize git
git init

# 2. Add all files
git add .

# 3. Create your first commit
git commit -m "feat: initial API with Dokploy Dockerfile configuration"

# 4. Set default branch to main
git branch -M main

# 5. Link to your GitHub repository (replace with your actual repo URL)
git remote add origin https://github.com/<YOUR_GITHUB_USERNAME>/<YOUR_REPO_NAME>.git

# 6. Push to GitHub
git push -u origin main
```

---

### Step 2: Connect Dokploy to GitHub

If your Dokploy server is not yet connected to your GitHub account:

1. Open your **Dokploy Dashboard** in your browser.
2. In the left navigation menu, click **Settings**.
3. Under **Git Providers**, select **GitHub**.
4. Click **Connect GitHub App** (or use personal access token / deploy keys).
5. Follow GitHub's prompt to grant Dokploy access to your repository (either all repositories or specifically `<YOUR_REPO_NAME>`).

---

### Step 3: Create the Application in Dokploy

1. In the Dokploy sidebar, click **Projects**.
2. Select an existing project (or click **Create Project**, e.g., name it `Escrow`).
3. Inside your project, click **Create Service** and choose **Application**.
4. Give it a name (e.g., `escrow-api`).

---

### Step 4: Configure Source & Build Type

Inside the newly created application:

1. **Source Tab**:
   - **Provider**: Select **GitHub**.
   - **Repository**: Choose your repository (e.g., `<username>/EscrowAPI`).
   - **Branch**: `main`.
2. **Build Tab**:
   - **Build Type**: Select **Dockerfile**.
   - **Dockerfile Path**: `./Dockerfile` (relative to the repo root).
   - **Context Path**: `./` (relative to the repo root).
3. Click **Save** at the bottom right.

---

### Step 5: Configure Port & Domain (Critical!)

Dokploy uses Traefik as its ingress reverse proxy. You must tell Dokploy which port your application listens to *inside* the container.

1. Go to the **Domains** tab in your Application settings.
2. Click **Add Domain**.
3. Configure the fields:
   - **Host / Domain**:
     - *For testing without a domain*: You can click the **Generate / Dice** button to get a free test domain (e.g., `escrow-api.traefik.me`).
     - *For production*: Enter your domain or subdomain (e.g., `api.yourdomain.com`). Ensure you have added an **A Record** in your DNS provider (Cloudflare, Namecheap, Route 53) pointing `api.yourdomain.com` to your VPS IP address.
   - **Container Port**: Set this to **`8080`**.
     > **Warning:** Do NOT set this to `80`, `5000`, or `5285`. .NET 8, 9, and 10 container images listen on `8080`. Entering the wrong port causes a `502 Bad Gateway`.
   - **Path**: `/`
   - **HTTPS**: Check **Certificate (Let's Encrypt)**.
4. Click **Save**.

---

### Step 6: Configure Environment Variables

1. Go to the **Environment** tab in your Dokploy application.
2. Add the following standard environment variables:

```ini
# Enables forwarded proxy headers so ASP.NET Core recognizes HTTPS from Traefik
ASPNETCORE_FORWARDEDHEADERS_ENABLED=true

# Set to Development if you want OpenAPI (/openapi/v1.json) accessible in production
# Or leave as Production once you add custom authorization or public routes
ASPNETCORE_ENVIRONMENT=Development
```

3. Click **Save**.

> **Pro Tip on `ASPNETCORE_FORWARDEDHEADERS_ENABLED=true`:**  
> In `Program.cs`, `app.UseHttpsRedirection()` is active. Because Dokploy's Traefik handles SSL on port 443 and speaks plain HTTP to your container on port 8080, setting `ASPNETCORE_FORWARDEDHEADERS_ENABLED=true` ensures ASP.NET Core recognizes that the client originally connected over HTTPS and avoids redirect loops.

---

### Step 7: Deploy and Enable Auto-Deploy

1. Navigate to the **Deployments** tab.
2. Click **Deploy**.
3. Dokploy will:
   - Pull the code from GitHub.
   - Run `docker build` using your multi-stage `Dockerfile`.
   - Start the container and register the route in Traefik.
4. Watch the deployment log stream in real time. Once the status shows **Running / Green**, your application is live!
5. In the **Source** or **Deployments** tab, ensure **Auto Deploy** (Webhooks) is turned **ON**. Every time you run `git push origin main`, Dokploy will automatically rebuild and deploy your changes with zero manual intervention.

---

### Step 8: Verify the Deployment

Test your live API via terminal or browser:

#### 1. Test Weather Forecast Endpoint
```bash
curl https://api.yourdomain.com/weatherforecast
```
**Expected Response:** JSON array with 5 forecast objects.

#### 2. Test OpenAPI Endpoint (if `ASPNETCORE_ENVIRONMENT=Development`)
```bash
curl https://api.yourdomain.com/openapi/v1.json
```
**Expected Response:** OpenAPI 3.0 specification JSON document.

---

## 4. Code Adjustments for Production (Optional but Recommended)

In `Program.cs`, you can optionally make your configuration even more resilient for reverse proxies and public documentation.

### Exposing OpenAPI & Scalar in Production
If you want the API documentation visible to users in production without setting `ASPNETCORE_ENVIRONMENT=Development`, update `Program.cs`:

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddOpenApi();

var app = builder.Build();

// Expose OpenAPI documentation regardless of environment
app.MapOpenApi();

// If you want Scalar interactive UI:
// app.MapScalarApiReference();

// Optional: Behind Traefik, HTTPS redirection is already handled by Dokploy.
// If ASPNETCORE_FORWARDEDHEADERS_ENABLED=true is set in Dokploy, this works seamlessly:
app.UseHttpsRedirection();

// ... endpoints ...

app.Run();
```

---

## 5. Troubleshooting & Diagnostics Matrix

| Symptom | Probable Cause | Solution |
| :--- | :--- | :--- |
| **`502 Bad Gateway`** | **Port mismatch:** Container Port in the Domains tab is not set to `8080`. | Go to the **Domains** tab in Dokploy, edit your domain, and set **Container Port** to `8080`. |
| **`502 Bad Gateway` (App Crash)** | Application threw an unhandled exception on startup. | Go to the **Logs** tab in Dokploy to see the exact C# stack trace. |
| **Infinite Redirect Loop / 307 Redirects** | `app.UseHttpsRedirection()` is fighting Traefik SSL termination. | Add `ASPNETCORE_FORWARDEDHEADERS_ENABLED=true` under the **Environment** tab in Dokploy. |
| **`404 Not Found` on `/openapi/v1.json`** | `MapOpenApi()` is only registered in `Development` environment. | Set `ASPNETCORE_ENVIRONMENT=Development` in the **Environment** tab or remove the `if (app.Environment.IsDevelopment())` condition in `Program.cs`. |
| **Docker Build fails with SDK not found** | Dokploy VPS cannot pull .NET 10 preview images or architecture issue. | If your server has trouble pulling preview images, verify internet access on the VPS. For LTS stability, switch `TargetFramework` to `net8.0` or `net9.0`. |
| **Domain SSL Error / "Not Secure"** | DNS A-Record not propagated or port 80/443 closed on VPS firewall. | Ensure VPS firewall allows ports 80 and 443 (`ufw allow 80/tcp && ufw allow 443/tcp`) so Let's Encrypt can complete HTTP-01 challenge. |

---

## 6. Daily Dokploy Management

- **View Live Logs:** Click on your application -> **Logs** tab to see real-time Kestrel logs and request output.
- **Resource Monitoring:** Click **Monitoring** to observe CPU, Memory, and Network usage.
- **Restarting:** Click the restart icon in the top right header to bounce the container.
- **Rollback:** Go to the **Deployments** tab to see past commit hashes and roll back to any previous working build with a single click.
