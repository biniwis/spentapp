import Foundation
import SwiftData

/// The set of models the store holds, pinned to a version.
///
/// Without a versioned schema SwiftData infers a lightweight migration on every launch and
/// gives no way to describe one that isn't lightweight. That works until the first change it
/// can't infer — a renamed property, a changed type, a new uniqueness constraint — and then
/// the container simply fails to open. Declaring the version now means the next change can
/// be expressed as a stage instead of a data loss.
///
/// When the models change: add `MoneyCitySchemaV2`, list it in `MoneyCityMigrationPlan.schemas`,
/// and add the `MigrationStage` between them. Adding an optional property with a default value
/// stays lightweight and only needs a new version number.
public enum MoneyCitySchemaV1: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    public static var models: [any PersistentModel.Type] {
        [
            Transaction.self,
            CityEnrichment.self,
            RecurringExpense.self,
            IncomeSource.self,
            CategoryBudget.self,
            MerchantRule.self,
            InstallmentPlan.self,
            SavingsGoal.self,
            IngestLogEntry.self
        ]
    }
}

/// The ordered history of schema versions. One version so far, so there are no stages yet.
public enum MoneyCityMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] { [MoneyCitySchemaV1.self] }
    public static var stages: [MigrationStage] { [] }
}
