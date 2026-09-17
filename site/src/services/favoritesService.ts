export interface FavoriteItem {
  id: string | number;
  title: string;
  imageUrl: string;
  type: 'anime' | 'manga';
  scoreOrTag?: string;
  savedAt: number;
}

const STORAGE_KEY = 'nekocast_favorites_v1';

export function getFavorites(): FavoriteItem[] {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return [];
    return JSON.parse(raw);
  } catch {
    return [];
  }
}

export function saveFavorites(items: FavoriteItem[]): void {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(items));
    window.dispatchEvent(new Event('nekocast_favorites_updated'));
  } catch (err) {
    console.error('Erro ao salvar favoritos:', err);
  }
}

export function isFavorite(id: string | number, type: 'anime' | 'manga'): boolean {
  const items = getFavorites();
  return items.some((item) => String(item.id) === String(id) && item.type === type);
}

export function toggleFavorite(item: Omit<FavoriteItem, 'savedAt'>): boolean {
  const current = getFavorites();
  const exists = current.some((f) => String(f.id) === String(item.id) && f.type === item.type);

  if (exists) {
    const filtered = current.filter((f) => !(String(f.id) === String(item.id) && f.type === item.type));
    saveFavorites(filtered);
    return false; // removido
  } else {
    current.unshift({ ...item, savedAt: Date.now() });
    saveFavorites(current);
    return true; // adicionado
  }
}
