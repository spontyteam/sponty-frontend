## 🔧 Git Workflow Guide for Feature Development and Releases

### 🔄 Branch Structure Overview

* `dev`: Main development branch
* `staging`: QA branch for testing integrated features
* `prod`: Production-ready, stable branch

---

### 1️⃣ Starting a New Feature

1. **Pull latest `dev`**:

   ```bash
   git checkout dev
   git pull origin dev
   ```

2. **Create a feature branch**:

   ```bash
   git checkout -b feature/<feature-name>
   ```

3. **Develop & Commit**:

   * Follow commit conventions (e.g., `feat:`, `fix:`, `docs:`)
   * Use atomic commits

   ```bash
   git add .
   git commit -m "feat: add new dashboard widget"
   ```

4. **Push the feature branch**:

   ```bash
   git push origin feature/<feature-name>
   ```

---

### 2️⃣ Merging Feature to `dev`

1. **Create a pull request (PR)**:

   * Base: `dev`
   * Compare: `feature/<feature-name>`

2. **Code review**:

   * Use reviewers & approval rules
   * Ensure CI passes

3. **Merge with squash (preferred)**:

   * Keeps `dev` history clean

4. **Delete feature branch (optional but recommended)**

---

### 3️⃣ Preparing `staging` for Testing

1. **Pull latest `dev`**:

   ```bash
   git checkout dev
   git pull origin dev
   ```

2. **Checkout `staging` and merge**:

   ```bash
   git checkout staging
   git pull origin staging
   git merge dev
   ```

3. **Resolve conflicts if any** → Test locally

4. **Push `staging`**:

   ```bash
   git push origin staging
   ```

5. **Deploy staging build**

---

### 4️⃣ Promoting to `prod`

> Only after QA approval in staging

1. **Ensure `staging` is up-to-date**:

   ```bash
   git checkout staging
   git pull origin staging
   ```

2. **Merge into `prod`**:

   ```bash
   git checkout prod
   git pull origin prod
   git merge staging
   ```

3. **Tag a version**:

   ```bash
   git tag -a v1.2.0 -m "Release v1.2.0"
   git push origin v1.2.0
   ```

4. **Push to `prod`**:

   ```bash
   git push origin prod
   ```

5. **Deploy to production**

---

### ✅ Versioning & Release Notes

* Follow [Semantic Versioning](https://semver.org/): `MAJOR.MINOR.PATCH`

  * `MAJOR`: breaking changes
  * `MINOR`: new features
  * `PATCH`: bug fixes

* Releases:

  * Use GitHub Releases tab
  * Attach changelog and release notes when tagging

---

### 🛡️ Safety & Consistency Tips

* **Always pull before merge or branch** (`git pull origin <branch>`)
* **Never commit directly to `dev`, `staging`, or `prod`**
* **Enable branch protection rules**:

  * Require PR review
  * Require status checks (CI)
* **Use squash merges** to avoid polluting history
* **Enable auto-deploys on `staging` and `prod`** using GitHub Actions (optional)
