# 🗺️ Enhanced Map & Admin Setup Guide

## 📋 **Overview**
This setup adds advanced map features with admin-managed featured parks, live dog counts, and Google Places integration.

## 🔧 **Required Setup Steps**

### **1. Database Setup (Supabase)**
Run the SQL commands in `SETUP_ENHANCED_MAP_DATABASE.sql`:

1. Open **Supabase Dashboard** → **SQL Editor**
2. Copy and paste the entire content of `SETUP_ENHANCED_MAP_DATABASE.sql`
3. Click **Run** to execute all commands

### **2. Enable Real-time Features**
1. Go to **Supabase Dashboard** → **API** → **Realtime**
2. Add `park_checkins` to the realtime tables
3. **Save changes**

### **3. Google Places API Setup**
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing one
3. Enable these APIs:
   - **Places API**
   - **Maps JavaScript API**
   - **Geocoding API**
4. Create an API Key:
   - Go to **APIs & Services** → **Credentials**
   - Click **Create Credentials** → **API Key**
   - **Restrict the key** to your domains for security
5. Add the API key to your environment:
   ```bash
   flutter run -d chrome --dart-define=GOOGLE_PLACES_API_KEY=your_api_key_here
   ```

### **4. Install Dependencies**
```bash
flutter pub get
```

## 🎯 **New Features**

### **✅ Live Dog Counts**
- Real-time display of how many dogs are at each park
- Updates automatically when users check in/out
- Color-coded markers and badges

### **⭐ Featured Parks (Admin)**
- Admin-curated parks with enhanced details
- Special orange star markers on map
- Custom descriptions, ratings, and amenities
- Google Places data integration

### **🔍 Distance-Based Sorting**
- Parks automatically sorted by distance from user
- Nearest parks shown first in the list
- Distance display in km/meters

### **👤 Admin Interface**
- Access via `yourdomain.com/#/admin`
- Search and select parks from Google Places
- Add custom descriptions and amenities
- Manage existing featured parks

## 📱 **How to Use**

### **For Users:**
1. **View Map**: See regular parks (green) and featured parks (orange ⭐)
2. **Check Dog Counts**: Numbers on markers show active dogs
3. **Park Details**: Tap markers or list items for full details
4. **Check In**: Use the "Check In" button to join a park
5. **Distance Info**: Parks are sorted by distance from your location

### **For Admins:**
1. **Access Admin Panel**: Navigate to `/admin` or click admin icon
2. **Search Google Places**: Find real parks with existing data
3. **Add Custom Info**: Enhance with your own descriptions and amenities  
4. **Manage Parks**: Edit or delete existing featured parks
5. **Combined Data**: Your custom info + Google's data with your branding

## 🎨 **Branding Colors**
- **Primary Green**: `#2E7D32` (BarkDate brand color)
- **Featured Orange**: `#FF9800` (for starred featured parks)
- **Success Green**: For active dog counts and positive states

## 🔐 **Security Features**
- **Row Level Security (RLS)** enabled on all tables
- Users can only check in/out themselves
- Admin features require authentication
- API keys are environment variables

## 📊 **Database Tables Created**
- `featured_parks` - Admin-curated parks with enhanced details
- `park_checkins` - Real-time dog check-in/out tracking
- Indexes for performance optimization
- RLS policies for security

## 🚀 **Next Steps**
1. Run the database setup
2. Configure Google Places API
3. Test the admin interface
4. Add your first featured parks
5. Users will see live dog counts and enhanced park details!

## 🐛 **Troubleshooting**

### **Google Places API Issues:**
- Ensure API key is correctly set in environment
- Check API quotas and billing in Google Cloud Console
- Verify API restrictions allow your domain

### **Real-time Not Working:**
- Confirm `park_checkins` is enabled in Supabase Realtime
- Check browser console for WebSocket errors
- Ensure proper RLS policies are set

### **Admin Access Issues:**
- Verify user is authenticated in Supabase
- Check if RLS policies allow the operation
- Ensure proper navigation to `/admin` route

## 📞 **Support**
If you encounter issues:
1. Check browser console for errors
2. Verify Supabase logs in dashboard
3. Ensure all SQL commands executed successfully
4. Confirm API keys are properly configured
