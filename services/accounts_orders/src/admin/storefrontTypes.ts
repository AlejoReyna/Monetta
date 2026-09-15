export interface AdminStorefrontConfigProjection {
  readonly id: string | null;
  readonly version: number;
  readonly announcement: string;
  readonly showHero: boolean;
  readonly showNewest: boolean;
  readonly showTodaysPicks: boolean;
  readonly showExternalPicks: boolean;
}
