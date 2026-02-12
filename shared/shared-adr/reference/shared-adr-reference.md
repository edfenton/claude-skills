# Shared ADR Reference

Templates and examples for Architecture Decision Records.

---

## ADR Template

```markdown
<!-- docs/adr/template.md -->
# [NUMBER]. [TITLE]

Date: YYYY-MM-DD
Status: proposed | accepted | deprecated | superseded by [ADR-XXXX](XXXX-xxx.md)

## Context

[Describe the issue or question that motivated this decision. Include:]
- What problem are we trying to solve?
- What constraints do we have?
- What forces are at play (technical, business, team)?

## Decision

[State the decision clearly and concisely.]

We will [do X].

## Alternatives Considered

### Alternative 1: [Name]
[Brief description]
- ✅ Pros
- ❌ Cons

### Alternative 2: [Name]
[Brief description]
- ✅ Pros
- ❌ Cons

## Consequences

### Positive
- [Good outcomes]

### Negative
- [Tradeoffs and downsides]

### Risks
- [Potential issues to monitor]

## References

- [Link to relevant documentation]
- [Link to discussion/RFC]
```

---

## Example: Initial ADR

```markdown
<!-- docs/adr/0001-record-architecture-decisions.md -->
# 1. Record Architecture Decisions

Date: 2025-01-24
Status: accepted

## Context

We need to record significant technical decisions made on this project so that:
- Future team members (including future us) understand why things were built this way
- We can revisit decisions when circumstances change
- We have a searchable history of our technical choices

## Decision

We will use Architecture Decision Records (ADRs), as described by Michael Nygard.

ADRs will be:
- Stored in `docs/adr/` in the repository
- Numbered sequentially (0001, 0002, etc.)
- Written in Markdown
- Kept short and focused on one decision each

## Consequences

### Positive
- Decisions are documented and searchable
- New team members can understand historical context
- Forces us to think through decisions clearly

### Negative
- Requires discipline to maintain
- Adds overhead to decision-making process

## References

- [Documenting Architecture Decisions](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions)
```

---

## Example: Technology Choice

```markdown
<!-- docs/adr/0002-use-mongodb-for-persistence.md -->
# 2. Use MongoDB for Persistence

Date: 2025-01-24
Status: accepted

## Context

We need a database for our application. Key requirements:
- Flexible schema for rapid iteration
- Good performance for read-heavy workloads
- Easy to scale horizontally
- Strong ecosystem and community support
- Team familiarity

Our data model includes:
- User profiles (semi-structured)
- Content items (varying schemas per type)
- Activity feeds (append-heavy)

## Decision

We will use MongoDB as our primary database, hosted on MongoDB Atlas.

## Alternatives Considered

### PostgreSQL
- ✅ Strong ACID guarantees
- ✅ Powerful query capabilities
- ❌ Schema migrations add friction during rapid iteration
- ❌ Horizontal scaling more complex

### DynamoDB
- ✅ Excellent scalability
- ✅ Managed service
- ❌ Limited query flexibility
- ❌ Vendor lock-in
- ❌ Steeper learning curve

### Supabase (PostgreSQL)
- ✅ Real-time subscriptions
- ✅ Built-in auth
- ❌ Less control over infrastructure
- ❌ Still requires schema migrations

## Consequences

### Positive
- Flexible schema allows rapid iteration
- Atlas provides managed infrastructure
- Mongoose ODM provides type safety
- Team has prior MongoDB experience

### Negative
- No native joins (must denormalize or use $lookup)
- Weaker transaction support than PostgreSQL
- Must be careful with document size limits

### Risks
- Schema flexibility could lead to inconsistent data if not disciplined
- Mitigation: Use Zod schemas for validation at API boundary

## References

- [MongoDB Atlas Documentation](https://docs.atlas.mongodb.com/)
- [Mongoose ODM](https://mongoosejs.com/)
```

---

## Example: Architecture Pattern

```markdown
<!-- docs/adr/0003-adopt-swiftui-mvvm-pattern.md -->
# 3. Adopt SwiftUI with MVVM Pattern

Date: 2025-01-24
Status: accepted

## Context

We're building a new iOS application and need to decide on:
- UI framework (UIKit vs SwiftUI)
- Architecture pattern (MVC, MVVM, TCA, etc.)

Key considerations:
- iOS 17+ minimum deployment target
- Small team (1-2 developers)
- Need for testability
- Rapid iteration during early development

## Decision

We will use SwiftUI with the MVVM (Model-View-ViewModel) pattern.

Specifically:
- Views are SwiftUI structs with minimal logic
- ViewModels are `@MainActor` classes with `@Published` state
- Dependencies injected via initializer
- Navigation handled via NavigationStack

## Alternatives Considered

### UIKit + MVC
- ✅ Mature, well-understood
- ✅ More control over UI details
- ❌ More boilerplate code
- ❌ Harder to test view logic
- ❌ Missing modern SwiftUI features

### SwiftUI + TCA (The Composable Architecture)
- ✅ Highly testable
- ✅ Predictable state management
- ❌ Steep learning curve
- ❌ Overkill for our app size
- ❌ Additional dependency

### SwiftUI + MV (Model-View)
- ✅ Simpler, less boilerplate
- ✅ Leverages SwiftUI's built-in state management
- ❌ Harder to test complex logic
- ❌ Can lead to bloated views

## Consequences

### Positive
- Clear separation of concerns
- ViewModels are easily unit testable
- Matches team's existing mental model
- Good balance of structure and pragmatism

### Negative
- Some boilerplate for ViewModel setup
- Must be disciplined about keeping Views thin
- State synchronization can be tricky

### Conventions
- ViewModels use `@Published private(set)` for state
- Public methods represent user intents
- No SwiftUI imports in ViewModels

## References

- [Apple SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [ios-std skill](../skills/ios/ios-std/SKILL.md)
```

---

## Example: Superseding ADR

```markdown
<!-- docs/adr/0007-migrate-to-drizzle-orm.md -->
# 7. Migrate to Drizzle ORM

Date: 2025-03-15
Status: accepted
Supersedes: [ADR-0002](0002-use-mongodb-for-persistence.md)

## Context

After 3 months of development, we've encountered several issues with MongoDB:
- Complex aggregations are becoming unwieldy
- We need stronger consistency for payment-related features
- The team is spending significant time on data integrity issues

Our data model has stabilized, reducing the need for schema flexibility.

## Decision

We will migrate from MongoDB to PostgreSQL using Drizzle ORM.

Migration strategy:
1. Set up PostgreSQL alongside MongoDB
2. Dual-write to both databases
3. Migrate read operations gradually
4. Verify data consistency
5. Remove MongoDB

## Consequences

### Positive
- ACID transactions for critical operations
- Powerful relational queries
- Drizzle provides type-safe query building

### Negative
- Migration effort (~2 weeks)
- Must update all data access code
- Schema migrations required for changes

## References

- [Drizzle ORM](https://orm.drizzle.team/)
- Previous decision: [ADR-0002](0002-use-mongodb-for-persistence.md)
```

---

## ADR Management Script

```bash
#!/bin/bash
# scripts/adr.sh

set -e

ADR_DIR="docs/adr"
TEMPLATE="$ADR_DIR/template.md"

# Ensure directory exists
mkdir -p "$ADR_DIR"

# Get next number
get_next_number() {
  last=$(ls "$ADR_DIR" | grep -E '^[0-9]{4}-' | sort -r | head -1 | cut -d'-' -f1)
  if [ -z "$last" ]; then
    echo "0001"
  else
    printf "%04d" $((10#$last + 1))
  fi
}

# Create new ADR
create_adr() {
  title="$1"
  slug=$(echo "$title" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-')
  number=$(get_next_number)
  filename="$ADR_DIR/$number-$slug.md"
  date=$(date +%Y-%m-%d)

  cat > "$filename" << EOF
# $number. $title

Date: $date
Status: proposed

## Context

[What is the issue we're facing?]

## Decision

[What have we decided to do?]

## Alternatives Considered

### Alternative 1
- ✅ Pros
- ❌ Cons

## Consequences

### Positive
- [Good outcomes]

### Negative
- [Tradeoffs]

## References

- [Links]
EOF

  echo "✅ Created: $filename"
  echo ""
  echo "Edit the file to add your decision details."
}

# List ADRs
list_adrs() {
  echo "Architecture Decision Records:"
  echo ""
  for file in "$ADR_DIR"/[0-9]*.md; do
    [ -f "$file" ] || continue
    number=$(basename "$file" | cut -d'-' -f1)
    title=$(head -1 "$file" | sed 's/^# [0-9]*\. //')
    status=$(grep -m1 "^Status:" "$file" | cut -d':' -f2 | tr -d ' ')
    printf "  %s: %s [%s]\n" "$number" "$title" "$status"
  done
}

# Main
case "${1:-}" in
  new|--new|-n)
    if [ -z "${2:-}" ]; then
      echo "Usage: $0 new <title>"
      exit 1
    fi
    shift
    create_adr "$*"
    ;;
  list|--list|-l)
    list_adrs
    ;;
  *)
    echo "Usage: $0 <command>"
    echo ""
    echo "Commands:"
    echo "  new <title>   Create a new ADR"
    echo "  list          List all ADRs"
    ;;
esac
```

---

## Package.json Scripts

```json
{
  "scripts": {
    "adr": "./scripts/adr.sh",
    "adr:new": "./scripts/adr.sh new",
    "adr:list": "./scripts/adr.sh list"
  }
}
```

---

## When to Write ADRs

| Write an ADR | Don't need an ADR |
|--------------|-------------------|
| Choosing database technology | Choosing variable names |
| Defining API authentication approach | Formatting preferences |
| Selecting state management pattern | Minor library updates |
| Deciding on deployment strategy | Bug fixes |
| Major refactoring decisions | Feature implementations |
| Security architecture choices | UI layout decisions |

---

## Tips for Good ADRs

1. **Keep them short** — One decision per ADR, 1-2 pages max
2. **Write context first** — Forces you to understand the problem
3. **Document alternatives** — Shows you considered options
4. **Be honest about tradeoffs** — List negatives, not just positives
5. **Link to related ADRs** — Build a connected knowledge base
6. **Update status** — Mark deprecated/superseded when things change
7. **Write them early** — Easier to document decisions while fresh
